defmodule Beacon.RuntimeCSS do
  @moduledoc """
  Runtime CSS for a site. Uses the Zig-based TailwindCompiler NIF for
  CSS generation and Beacon.CSS.Storage for three-tier caching
  (ETS → S3 → recompile).
  """

  require Logger

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
    candidates = collect_all_candidates(site)
    candidate_list = MapSet.to_list(candidates)

    case compile_from_candidates(site, candidate_list) do
      {:ok, css} ->
        Beacon.CSS.Storage.store(site, css, candidates)
        :ok

      {:error, error} ->
        raise Beacon.LoaderError, "failed to compile css: #{inspect(error)}"
    end
  end

  @doc false
  def current_hash(site) do
    {hash, _brotli, _gzip} = ensure_compiled(site)
    hash
  end

  @doc false
  def config(_site), do: ""

  defp ensure_compiled(site) do
    Beacon.CSS.Storage.fetch(site)
  end

  defp collect_all_candidates(site) do
    alias Beacon.CSS.CandidateExtractor

    # Scan ALL published page templates from DB — not just pages loaded in ETS.
    # With lazy loading, only requested pages are in ETS. CSS needs candidates
    # from every page on the site.
    page_candidates =
      Beacon.Content.list_published_pages_snapshot_data(site)
      |> Enum.reduce(MapSet.new(), fn page, acc ->
        template = Beacon.Lifecycle.Template.load_template(page)
        MapSet.union(acc, CandidateExtractor.extract(template))
      end)

    # Layout candidates
    layout_candidates =
      Beacon.Content.list_published_layouts(site)
      |> Enum.reduce(MapSet.new(), fn layout, acc ->
        MapSet.union(acc, CandidateExtractor.extract(layout.template))
      end)

    # Component candidates
    component_candidates =
      Beacon.Content.list_components(site, per_page: :infinity)
      |> Enum.reduce(MapSet.new(), fn component, acc ->
        MapSet.union(acc, CandidateExtractor.extract(component.template))
      end)

    # Host app safelist from compiled module
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

    page_candidates
    |> MapSet.union(layout_candidates)
    |> MapSet.union(component_candidates)
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
