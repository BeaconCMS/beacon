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

    # Page candidates from ETS (extracted at publish_page time)
    page_candidates =
      :ets.match(:beacon_runtime_poc, {{site, :_, :css_candidates}, :"$1"})
      |> Enum.reduce(MapSet.new(), fn [candidates], acc -> MapSet.union(acc, candidates) end)

    # Layout candidates — extract from published layout templates
    layout_candidates =
      Beacon.Content.list_published_layouts(site)
      |> Enum.reduce(MapSet.new(), fn layout, acc ->
        MapSet.union(acc, CandidateExtractor.extract(layout.template))
      end)

    # Component candidates — extract from all component templates
    component_candidates =
      Beacon.Content.list_components(site, per_page: :infinity)
      |> Enum.reduce(MapSet.new(), fn component, acc ->
        MapSet.union(acc, CandidateExtractor.extract(component.template))
      end)

    # Site-wide set from ETS
    site_candidates =
      case :ets.lookup(:beacon_runtime_poc, {site, :css_candidates}) do
        [{_, candidates}] -> candidates
        [] -> MapSet.new()
      end

    page_candidates
    |> MapSet.union(layout_candidates)
    |> MapSet.union(component_candidates)
    |> MapSet.union(site_candidates)
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
