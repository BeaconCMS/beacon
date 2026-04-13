defmodule Beacon.SEO.JsonLd do
  @moduledoc """
  Auto-generates JSON-LD structured data from page and site metadata.

  Produces Schema.org objects based on the page type and site configuration:

    * `Article` / `BlogPosting` — when `page_type` is `"article"`
    * `BreadcrumbList` — for all pages with path depth >= 2
    * `Organization` — on the root page when configured
    * `WebSite` — on the root page when configured

  Auto-generated schemas are merged with any manual `raw_schema` entries.
  Manual entries take precedence — if a manual schema has the same `@type`,
  the auto-generated one is suppressed.
  """

  @doc """
  Builds a list of JSON-LD objects for a page.

  Returns a list of maps, each representing a JSON-LD object ready for
  `Jason.encode!/1`.
  """
  @spec build(map(), map(), Beacon.Config.t()) :: [map()]
  def build(manifest, _layout_manifest, config) do
    base_url = Beacon.RuntimeRenderer.public_site_url(config.site)
    schemas = []

    # Universal schemas
    schemas = case breadcrumb_schema(manifest[:path], base_url) do
      nil -> schemas
      breadcrumb -> [breadcrumb | schemas]
    end

    schemas = if root_page?(manifest[:path]) do
      schemas = case organization_schema(config, base_url) do
        nil -> schemas
        org -> [org | schemas]
      end

      case website_schema(config, base_url) do
        nil -> schemas
        ws -> [ws | schemas]
      end
    else
      schemas
    end

    # Template-type-defined JSON-LD
    schemas = case resolve_template_type_json_ld(manifest, config) do
      nil -> schemas
      tt_schema -> [tt_schema | schemas]
    end

    Enum.reverse(schemas)
  end

  defp resolve_template_type_json_ld(manifest, config) do
    case manifest[:template_type] do
      %{json_ld_mapping: mapping} when is_map(mapping) and map_size(mapping) > 0 ->
        Beacon.TemplateType.JsonLdResolver.resolve(
          mapping,
          manifest[:fields] || %{},
          manifest,
          config
        )
      _ -> nil
    end
  end

  @doc """
  Builds a BreadcrumbList schema from a URL path.

  Returns `nil` for root paths or paths with only one segment.
  """
  @spec breadcrumb_schema(String.t() | nil, String.t()) :: map() | nil
  def breadcrumb_schema(nil, _base_url), do: nil
  def breadcrumb_schema("/", _base_url), do: nil

  def breadcrumb_schema(path, base_url) do
    segments =
      path
      |> String.trim_leading("/")
      |> String.split("/")
      |> Enum.reject(&(&1 == ""))

    if length(segments) < 1 do
      nil
    else
      items =
        [{"Home", base_url} | build_breadcrumb_items(segments, base_url)]
        |> Enum.with_index(1)
        |> Enum.map(fn {{name, url}, position} ->
          item = %{"@type" => "ListItem", "position" => position, "name" => name}
          if url, do: Map.put(item, "item", url), else: item
        end)

      %{
        "@context" => "https://schema.org",
        "@type" => "BreadcrumbList",
        "itemListElement" => items
      }
    end
  end

  @doc """
  Builds an Organization schema from site config.

  Returns `nil` if no organization data is configured.
  """
  @spec organization_schema(Beacon.Config.t(), String.t()) :: map() | nil
  def organization_schema(config, base_url) do
    org = Map.get(config, :organization)

    if is_map(org) and map_size(org) > 0 do
      schema = %{
        "@context" => "https://schema.org",
        "@type" => "Organization"
      }

      schema = put_if(schema, "name", org[:name] || config.site_name)
      schema = put_if(schema, "url", org[:url] || base_url)
      schema = put_if(schema, "logo", org[:logo])
      schema = put_if(schema, "sameAs", org[:same_as])
      schema
    else
      nil
    end
  end

  @doc """
  Builds a WebSite schema with optional SearchAction.

  Returns `nil` if no site_name is configured.
  """
  @spec website_schema(Beacon.Config.t(), String.t()) :: map() | nil
  def website_schema(config, base_url) do
    if config.site_name do
      schema = %{
        "@context" => "https://schema.org",
        "@type" => "WebSite",
        "name" => config.site_name,
        "url" => base_url
      }

      schema = if search_url = Map.get(config, :search_action_url_template) do
        Map.put(schema, "potentialAction", %{
          "@type" => "SearchAction",
          "target" => search_url,
          "query-input" => "required name=search_term_string"
        })
      else
        schema
      end

      schema
    else
      nil
    end
  end

  @doc """
  Builds a FAQPage schema from page FAQ items.


  @doc """
  Merges auto-generated schemas with manual raw_schema entries.

  Manual entries take precedence — if a manual schema has the same `@type`,
  the auto-generated one is suppressed.
  """
  @spec merge(list(), list()) :: list()
  def merge(auto_schemas, manual_schemas) do
    manual_types = MapSet.new(manual_schemas, fn s -> s["@type"] end)

    filtered_auto =
      Enum.reject(auto_schemas, fn s ->
        MapSet.member?(manual_types, s["@type"])
      end)

    manual_schemas ++ filtered_auto
  end

  # -- Private helpers --

  defp root_page?("/"), do: true
  defp root_page?(_), do: false

  defp build_breadcrumb_items(segments, base_url) do
    segments
    |> Enum.with_index()
    |> Enum.map(fn {segment, idx} ->
      accumulated_path = Enum.take(segments, idx + 1) |> Enum.join("/")
      name = segment |> String.replace(~r/[-_]/, " ") |> titlecase()
      is_last = idx == length(segments) - 1
      url = if is_last, do: nil, else: "#{base_url}/#{accumulated_path}"
      {name, url}
    end)
  end

  defp titlecase(str) do
    str
    |> String.split(" ")
    |> Enum.map_join(" ", fn word ->
      case String.split_at(word, 1) do
        {"", ""} -> ""
        {first, rest} -> String.upcase(first) <> rest
      end
    end)
  end

  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
  defp format_datetime(str) when is_binary(str), do: str
  defp format_datetime(_), do: nil

  defp put_if(map, _key, nil), do: map
  defp put_if(map, _key, ""), do: map
  defp put_if(map, _key, []), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)
end
