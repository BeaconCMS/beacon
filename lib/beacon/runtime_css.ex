defmodule Beacon.RuntimeCSS do
  @moduledoc """
  Runtime CSS for a site. Uses the Zig-based TailwindCompiler NIF for
  CSS generation and Beacon.CSS.Storage for three-tier caching
  (ETS → S3 → recompile).
  """

  require Logger

  @warming_hash "warming"

  @doc false
  def compile_from_candidates(site, candidates) when is_atom(site) and is_list(candidates) do
    theme_json = load_theme_json(site)
    custom_css = collect_custom_css(site)

    case TailwindCompiler.compile(candidates,
           theme: theme_json,
           preflight: true,
           custom_css: custom_css
         ) do
      {:ok, css} -> {:ok, css}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  def fetch(site, version \\ :brotli)

  def fetch(site, :brotli) do
    {_hash, brotli, _gzip} = ensure_compiled(site)
    brotli || "/* CSS compilation failed */"
  end

  def fetch(site, :gzip) do
    {_hash, _brotli, gzip} = ensure_compiled(site)
    gzip || "/* CSS compilation failed */"
  end

  def fetch(site, :deflate) do
    {_hash, _brotli, gzip} = ensure_compiled(site)
    if gzip, do: :zlib.gunzip(gzip), else: "/* CSS compilation failed */"
  end

  @doc false
  def load!(site) do
    mem_start = mem_mb()
    t0 = System.monotonic_time(:millisecond)

    candidates = collect_all_candidates(site)
    mem_after_candidates = mem_mb()
    t1 = System.monotonic_time(:millisecond)

    candidate_list = MapSet.to_list(candidates)

    case compile_from_candidates(site, candidate_list) do
      {:ok, css} ->
        mem_after_compile = mem_mb()
        t2 = System.monotonic_time(:millisecond)

        Beacon.CSS.Storage.store(site, css, candidates)
        mem_after_store = mem_mb()
        t3 = System.monotonic_time(:millisecond)

        Logger.info("""
        [Beacon.CSS] Warming complete for #{site}
          candidates:  #{MapSet.size(candidates)} classes, #{t1 - t0}ms, #{mem_start}MB → #{mem_after_candidates}MB (+#{mem_after_candidates - mem_start}MB)
          compile:     #{byte_size(css)} bytes CSS, #{t2 - t1}ms, → #{mem_after_compile}MB (+#{mem_after_compile - mem_after_candidates}MB)
          compress:    #{t3 - t2}ms, → #{mem_after_store}MB (+#{mem_after_store - mem_after_compile}MB)
          total:       #{t3 - t0}ms, #{mem_start}MB → #{mem_after_store}MB (+#{mem_after_store - mem_start}MB)
        """)

        :ok

      {:error, error} ->
        raise Beacon.LoaderError, "failed to compile css: #{inspect(error)}"
    end
  end

  defp mem_mb, do: div(:erlang.memory(:total), 1_048_576)

  @doc false
  def current_hash(site) do
    case :ets.lookup(:beacon_assets, {site, :css}) do
      [{_, {hash, _brotli, _gzip}}] when is_binary(hash) ->
        hash

      _ ->
        compile_async(site)
        @warming_hash
    end
  end

  @doc """
  Returns true if compiled CSS is available in cache for the given site.
  Non-blocking — only checks ETS, never triggers compilation.
  """
  def css_ready?(site) do
    case :ets.lookup(:beacon_assets, {site, :css}) do
      [{_, {hash, _brotli, _gzip}}] when is_binary(hash) -> true
      _ -> false
    end
  end

  @doc """
  Returns the sentinel hash used when CSS is still compiling.
  """
  def warming_hash, do: @warming_hash

  @doc false
  def config(_site), do: ""

  @doc """
  Kicks off CSS compilation in a background task if not already running.
  When compilation completes, broadcasts `:css_compiled` via PubSub.
  """
  def compile_async(site) do
    key = {site, :css_compiling}

    # Only start one compilation at a time per site
    if :ets.insert_new(:beacon_assets, {key, true}) do
      Task.start(fn ->
        try do
          t0 = System.monotonic_time(:millisecond)
          load!(site)
          elapsed = System.monotonic_time(:millisecond) - t0
          Logger.info("[Beacon.CSS] Compiled CSS for #{site} in #{elapsed}ms")
          Beacon.PubSub.css_compiled(site)
        rescue
          e -> Logger.error("[Beacon.CSS] Compilation failed for #{site}: #{Exception.message(e)}")
        after
          :ets.delete(:beacon_assets, key)
        end
      end)
    end

    :ok
  end

  defp ensure_compiled(site) do
    if safelist_recompiled?(site) or nif_recompiled?(site) do
      :ets.delete(:beacon_assets, {site, :css})
      :ets.delete(:beacon_assets, {site, :css_compile})
      load!(site)
    end

    Beacon.CSS.Storage.fetch(site)
  end

  defp safelist_recompiled?(site) do
    module = Beacon.Config.fetch!(site) |> Map.get(:css_safelist_module)
    key = {site, :css_safelist_mtime}

    with module when not is_nil(module) <- module,
         true <- Code.ensure_loaded?(module),
         path when is_list(path) <- :code.which(module),
         {:ok, %{mtime: mtime}} <- File.stat(List.to_string(path)),
         [{_, ^mtime}] <- :ets.lookup(:beacon_assets, key) do
      false
    else
      [{_, _prev}] ->
        with module when not is_nil(module) <- module,
             path when is_list(path) <- :code.which(module),
             {:ok, %{mtime: mtime}} <- File.stat(List.to_string(path)) do
          :ets.insert(:beacon_assets, {key, mtime})
        end

        true

      [] ->
        with module when not is_nil(module) <- module,
             path when is_list(path) <- :code.which(module),
             {:ok, %{mtime: mtime}} <- File.stat(List.to_string(path)) do
          :ets.insert(:beacon_assets, {key, mtime})
        end

        false

      _ ->
        false
    end
  end

  defp nif_recompiled?(site) do
    key = {site, :css_nif_mtime}

    with path when is_list(path) <- :code.which(TailwindCompiler.NIF),
         {:ok, %{mtime: mtime}} <- File.stat(List.to_string(path)),
         [{_, ^mtime}] <- :ets.lookup(:beacon_assets, key) do
      false
    else
      [{_, _prev}] ->
        with path when is_list(path) <- :code.which(TailwindCompiler.NIF),
             {:ok, %{mtime: mtime}} <- File.stat(List.to_string(path)) do
          :ets.insert(:beacon_assets, {key, mtime})
        end

        true

      [] ->
        with path when is_list(path) <- :code.which(TailwindCompiler.NIF),
             {:ok, %{mtime: mtime}} <- File.stat(List.to_string(path)) do
          :ets.insert(:beacon_assets, {key, mtime})
        end

        false

      _ ->
        false
    end
  end

  defp collect_all_candidates(site) do
    alias Beacon.CSS.CandidateExtractor

    m0 = mem_mb()
    t0 = System.monotonic_time(:millisecond)

    pages = Beacon.Content.list_published_pages_snapshot_data(site)
    m1 = mem_mb()
    t1 = System.monotonic_time(:millisecond)

    page_candidates =
      Enum.reduce(pages, MapSet.new(), fn page, acc ->
        MapSet.union(acc, CandidateExtractor.extract(page.template))
      end)

    m2 = mem_mb()
    t2 = System.monotonic_time(:millisecond)

    layout_candidates =
      Beacon.Content.list_published_layouts(site)
      |> Enum.reduce(MapSet.new(), fn layout, acc ->
        MapSet.union(acc, CandidateExtractor.extract(layout.template))
      end)

    component_candidates =
      Beacon.Content.list_components(site, per_page: :infinity)
      |> Enum.reduce(MapSet.new(), fn component, acc ->
        MapSet.union(acc, CandidateExtractor.extract(component.template))
      end)

    error_page_candidates =
      Beacon.Content.list_error_pages(site, per_page: :infinity)
      |> Enum.reduce(MapSet.new(), fn error_page, acc ->
        MapSet.union(acc, CandidateExtractor.extract(error_page.template))
      end)

    safelist_candidates =
      case Beacon.Config.fetch!(site) do
        %{css_safelist_module: module} when not is_nil(module) ->
          if Code.ensure_loaded?(module) and function_exported?(module, :list, 0) do
            module.list() |> MapSet.new()
          else
            MapSet.new()
          end

        _ ->
          MapSet.new()
      end

    m3 = mem_mb()
    t3 = System.monotonic_time(:millisecond)

    Logger.info("""
    [Beacon.CSS] Candidate extraction for #{site}
      load snapshots: #{length(pages)} pages, #{t1 - t0}ms, #{m0}MB → #{m1}MB (+#{m1 - m0}MB)
      extract pages:  #{MapSet.size(page_candidates)} classes, #{t2 - t1}ms, → #{m2}MB (+#{m2 - m1}MB)
      layouts+components+errors+safelist: #{t3 - t2}ms, → #{m3}MB (+#{m3 - m2}MB)
    """)

    page_candidates
    |> MapSet.union(layout_candidates)
    |> MapSet.union(component_candidates)
    |> MapSet.union(error_page_candidates)
    |> MapSet.union(safelist_candidates)
  end

  defp load_theme_json(site) do
    config = Beacon.Config.fetch!(site)

    if config.tailwind_config && File.exists?(config.tailwind_config) do
      Beacon.CSS.ThemeParser.parse_file(config.tailwind_config)
    end
  end

  defp collect_custom_css(site) do
    stylesheets =
      site
      |> Beacon.Content.list_stylesheets()
      |> Enum.map_join("\n", fn s -> s.content end)

    if stylesheets == "", do: nil, else: stylesheets
  end
end
