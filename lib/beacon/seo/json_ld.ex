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

    schemas = if manifest[:page_type] == "article" do
      [article_schema(manifest, config, base_url) | schemas]
    else
      schemas
    end

    schemas = case breadcrumb_schema(manifest[:path], base_url) do
      nil -> schemas
      breadcrumb -> [breadcrumb | schemas]
    end

    schemas = case faq_page_schema(manifest) do
      nil -> schemas
      faq -> [faq | schemas]
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

    Enum.reverse(schemas)
  end

  @doc """
  Builds an Article schema from page metadata.
  """
  @spec article_schema(map(), Beacon.Config.t(), String.t()) :: map()
  def article_schema(manifest, config, base_url) do
    schema = %{
      "@context" => "https://schema.org",
      "@type" => "Article",
      "headline" => manifest[:og_title] || manifest[:title] || "",
      "url" => manifest[:canonical_url] || "#{base_url}#{manifest[:path] || "/"}"
    }

    schema = put_if(schema, "description", manifest[:meta_description] || manifest[:description])
    schema = put_if(schema, "image", manifest[:og_image])

    schema = if manifest[:inserted_at] do
      Map.put(schema, "datePublished", format_datetime(manifest[:inserted_at]))
    else
      schema
    end

    schema = case manifest[:date_modified] || manifest[:updated_at] do
      nil -> schema
      dt -> Map.put(schema, "dateModified", format_datetime(dt))
    end

    schema = if config.site_name do
      Map.put(schema, "publisher", %{
        "@type" => "Organization",
        "name" => config.site_name
      })
    else
      schema
    end

    schema
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

  Returns `nil` if no valid FAQ items are present. Only includes items
  where both question and answer are non-empty strings.
  """
  @spec faq_page_schema(map()) :: map() | nil
  def faq_page_schema(manifest) do
    items = manifest[:faq_items] || []

    valid_items =
      Enum.filter(items, fn item ->
        q = item["question"] || item[:question]
        a = item["answer"] || item[:answer]
        is_binary(q) and q != "" and is_binary(a) and a != ""
      end)

    if valid_items == [] do
      nil
    else
      %{
        "@context" => "https://schema.org",
        "@type" => "FAQPage",
        "mainEntity" =>
          Enum.map(valid_items, fn item ->
            %{
              "@type" => "Question",
              "name" => item["question"] || item[:question],
              "acceptedAnswer" => %{
                "@type" => "Answer",
                "text" => item["answer"] || item[:answer]
              }
            }
          end)
      }
    end
  end

  @doc """
  Builds a Person schema from an author record.
  """
  @spec person_schema(map(), String.t()) :: map()
  def person_schema(author, base_url) when is_map(author) do
    schema = %{
      "@context" => "https://schema.org",
      "@type" => "Person",
      "name" => author[:name] || author["name"] || ""
    }

    schema = put_if(schema, "jobTitle", author[:job_title] || author["job_title"])
    schema = put_if(schema, "description", author[:bio] || author["bio"])
    schema = put_if(schema, "image", author[:avatar_url] || author["avatar_url"])

    slug = author[:slug] || author["slug"]
    schema = if slug, do: Map.put(schema, "url", "#{base_url}/blog/authors/#{slug}"), else: schema

    same_as = author[:same_as] || author["same_as"] || []
    schema = if same_as != [], do: Map.put(schema, "sameAs", same_as), else: schema

    schema
  end

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
