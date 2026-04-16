defmodule Beacon.Web.Layouts do
  @moduledoc """
  Core layouts.

  These functions are mostly used internally by Beacon but you can override the
  root layout in `beacon_site` so you should use the functions in this
  module to properly build your custom root layout to avoid breaking
  Beacon functionality.

  See https://github.com/BeaconCMS/beacon/blob/main/lib/beacon/web/components/layouts/runtime.html.heex for reference.

  """

  use Beacon.Web, :html
  require Logger

  embed_templates "layouts/*"

  @doc """
  Returns the path to the route that serves CSS and JS assets.
  """
  # TODO: style nonce
  def asset_path(conn, asset) when asset in [:css, :js] do
    site = site(conn)
    router = router(conn)
    prefix = router.__beacon_scoped_prefix_for_site__(site)

    hash =
      cond do
        asset == :css -> Beacon.RuntimeCSS.current_hash(site)
        asset == :js -> Beacon.RuntimeJS.current_hash(site)
      end

    path = Beacon.Router.sanitize_path("#{prefix}/__beacon_assets__/#{asset}-#{hash}")
    Phoenix.VerifiedRoutes.unverified_path(conn, router, path)
  end

  defp site(%{assigns: %{beacon: %{site: site}}}), do: site

  defp site(_site) do
    Logger.error("Failed to find site to serve assets")
    nil
  end

  defp router(%Plug.Conn{private: %{phoenix_router: router}}), do: router
  defp router(%Phoenix.LiveView.Socket{router: router}), do: router

  @doc false
  def render_dynamic_layout(assigns) do
    %{beacon: %{site: site, private: %{layout_id: layout_id}}} = assigns

    case Beacon.RuntimeRenderer.render_layout(site, layout_id, assigns) do
      {:ok, rendered} ->
        rendered

      {:error, :not_found} ->
        require Logger
        Logger.error("[Beacon] Layout #{layout_id} not found in ETS for site #{site}")
        assigns.inner_content
    end
  end

  @doc """
  Returns the path to the live socket defined in the site configuration.
  """
  def live_socket_path(assigns) do
    %{beacon: %{site: site}} = assigns
    Beacon.Config.fetch!(site).live_socket_path
  end

  @doc """
  Returns the resolved page title.

  Page titles may use snippets to render dynamic content.
  This function will resolve such snippets.
  """
  def render_page_title(assigns) do
    %{beacon: %{site: site, page: %{title: title, path: path}, private: %{page_id: page_id}}} = assigns

    page_assigns = %{site: site, id: page_id, path: path, title: title}

    rendered =
      case Beacon.Content.render_snippet(title, %{page: page_assigns, data: assigns}) do
        {:ok, rendered_title} -> rendered_title
        {:error, _} -> title
      end

    apply_title_template(rendered, site, assigns)
  end

  defp apply_title_template(rendered_title, site, assigns) do
    manifest = Beacon.RuntimeRenderer.fetch_manifest!(site, assigns.beacon.private.page_id)
    page_override = Map.get(manifest.extra || %{}, "title_template")

    cond do
      page_override == "none" ->
        rendered_title

      is_binary(page_override) ->
        page_override
        |> String.replace("{page_title}", rendered_title)
        |> String.replace("{site_name}", Beacon.Config.fetch!(site).site_name || "")

      true ->
        case Beacon.Config.fetch!(site).title_template do
          nil -> rendered_title
          template ->
            template
            |> String.replace("{page_title}", rendered_title)
            |> String.replace("{site_name}", Beacon.Config.fetch!(site).site_name || "")
        end
    end
  end

  @doc """
  Renders all `<meta>` tags defined in the current page.
  """
  def render_meta_tags(assigns) do
    ~H"""
    <%= for meta_attributes <- Beacon.Web.DataSource.meta_tags(assigns) do %>
      <meta {meta_attributes} />
    <% end %>
    """
  end

  @doc false
  def meta_tags(assigns) do
    layout_tags = layout_meta_tags(assigns) || []
    site_defaults = Beacon.Content.default_site_meta_tags()
    seo_tags = build_seo_meta_tags(assigns)

    case assigns do
      %{beacon_meta_tags: override_tags} when is_list(override_tags) ->
        override_tags
        |> deduplicate_meta_tags(seo_tags)
        |> deduplicate_meta_tags(layout_tags)
        |> deduplicate_meta_tags(site_defaults)
        |> Enum.reject(&(&1["name"] == "csrf-token"))

      _ ->
        page_tags = page_meta_tags(assigns) || []

        page_tags
        |> deduplicate_meta_tags(seo_tags)
        |> deduplicate_meta_tags(layout_tags)
        |> deduplicate_meta_tags(site_defaults)
        |> Enum.reject(&(&1["name"] == "csrf-token"))
    end
  end

  # Builds meta tags from first-class SEO fields on page, layout, and config.
  # Only activates when at least one SEO field is explicitly set on the page,
  # layout, or config. When no SEO fields are configured, returns [].
  defp build_seo_meta_tags(%{beacon: %{site: site, private: %{page_id: page_id, layout_id: layout_id}}}) do
    manifest = Beacon.RuntimeRenderer.fetch_manifest!(site, page_id)
    layout_manifest = case Beacon.RuntimeRenderer.fetch_layout_manifest(site, layout_id) do
      {:ok, lm} -> lm
      :error -> %{}
    end
    config = Beacon.Config.fetch!(site)

    # Only generate auto-tags when at least one SEO field is explicitly configured
    has_page_seo = Enum.any?(~w(meta_description canonical_url og_title og_description og_image twitter_card)a,
      fn field -> non_empty?(manifest[field]) end)
    has_layout_seo = non_empty?(layout_manifest[:default_og_image]) or non_empty?(layout_manifest[:default_twitter_card])
    has_config_seo = non_empty?(config.site_name) or non_empty?(config.twitter_site) or
      non_empty?(config.fb_app_id) or non_empty?(config.default_og_image)

    unless has_page_seo or has_layout_seo or has_config_seo do
      return_empty()
    else
      do_build_seo_meta_tags(manifest, layout_manifest, config)
    end
  end

  defp build_seo_meta_tags(_assigns), do: []

  defp return_empty, do: []

  defp do_build_seo_meta_tags(manifest, layout_manifest, config) do
    tags = []

    # description — from meta_description or fallback to description
    desc = manifest[:meta_description] || manifest[:description]
    tags = if non_empty?(desc), do: [%{"name" => "description", "content" => desc} | tags], else: tags

    # og:title — from og_title or fallback to title
    og_title = manifest[:og_title] || manifest[:title]
    tags = if non_empty?(og_title), do: [%{"property" => "og:title", "content" => og_title} | tags], else: tags

    # og:description — from og_description or fallback to description
    og_desc = manifest[:og_description] || desc
    tags = if non_empty?(og_desc), do: [%{"property" => "og:description", "content" => og_desc} | tags], else: tags

    # og:image — cascade: page → layout → config
    og_image = manifest[:og_image] || layout_manifest[:default_og_image] || config.default_og_image
    tags = if non_empty?(og_image), do: [%{"property" => "og:image", "content" => og_image} | tags], else: tags

    # og:image dimensions
    tags = if non_empty?(og_image) do
      case config.default_og_image_dimensions do
        {w, h} ->
          [%{"property" => "og:image:width", "content" => to_string(w)},
           %{"property" => "og:image:height", "content" => to_string(h)} | tags]
        _ -> tags
      end
    else
      tags
    end

    # og:type — defaults to "website", template types override via meta_tag_mapping
    tags = [%{"property" => "og:type", "content" => "website"} | tags]

    # og:url — canonical URL
    og_url = manifest[:canonical_url] || Beacon.RuntimeRenderer.public_page_url(config.site, %{path: manifest[:path]})
    tags = if non_empty?(og_url), do: [%{"property" => "og:url", "content" => og_url} | tags], else: tags

    # og:site_name
    tags = if non_empty?(config.site_name), do: [%{"property" => "og:site_name", "content" => config.site_name} | tags], else: tags

    # twitter:card — cascade: page → layout → config
    twitter_card = manifest[:twitter_card] || layout_manifest[:default_twitter_card] || config.default_twitter_card
    tags = if non_empty?(twitter_card), do: [%{"name" => "twitter:card", "content" => twitter_card} | tags], else: tags

    # twitter:site
    tags = if non_empty?(config.twitter_site), do: [%{"name" => "twitter:site", "content" => config.twitter_site} | tags], else: tags

    # fb:app_id
    tags = if non_empty?(config.fb_app_id), do: [%{"property" => "fb:app_id", "content" => config.fb_app_id} | tags], else: tags

    # Collection meta tags (resolved from mapping, integrated via dedup)
    tags = case manifest[:collection] do
      %{meta_tag_mapping: mapping} when is_list(mapping) and length(mapping) > 0 ->
        col_tags = Beacon.Collection.MetaTagResolver.resolve(mapping, manifest[:fields] || %{}, manifest, config)
        deduplicate_meta_tags(col_tags, tags)
      _ -> tags
    end

    Enum.reverse(tags)
  end

  defp non_empty?(nil), do: false
  defp non_empty?(""), do: false
  defp non_empty?(_), do: true

  # Merges two meta tag lists. Tags in `higher` take priority over `lower`.
  # Deduplication key is the first present of: "property", "name", "http-equiv".
  # Tags without any key (e.g. charset) are always included from both lists.
  defp deduplicate_meta_tags(higher, lower) do
    higher_keys =
      higher
      |> Enum.map(&meta_tag_key/1)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    filtered_lower =
      Enum.filter(lower, fn tag ->
        case meta_tag_key(tag) do
          nil -> true
          key -> not MapSet.member?(higher_keys, key)
        end
      end)

    higher ++ filtered_lower
  end

  defp meta_tag_key(tag) when is_map(tag) do
    tag["property"] || tag["name"] || tag["http-equiv"]
  end

  defp page_meta_tags(%{beacon: %{site: site, private: %{page_id: page_id}}}) do
    manifest = Beacon.RuntimeRenderer.fetch_manifest!(site, page_id)
    manifest.meta_tags || []
  end

  defp layout_meta_tags(%{beacon: %{site: site, private: %{layout_id: layout_id}}}) do
    case Beacon.RuntimeRenderer.fetch_layout_manifest(site, layout_id) do
      {:ok, manifest} -> manifest.meta_tags || []
      :error -> []
    end
  end

  defp layout_meta_tags(_assigns), do: []

  @doc """
  Renders the `<link rel="canonical">` tag for the current page.

  Auto-generates from the site's public URL + page path unless the page
  overrides it via `extra["canonical_url"]`.
  """
  def render_canonical_link(%{beacon: %{site: site, private: %{page_id: page_id}}} = assigns) do
    manifest = Beacon.RuntimeRenderer.fetch_manifest!(site, page_id)

    canonical_url =
      cond do
        non_empty?(manifest[:canonical_url]) -> manifest[:canonical_url]
        non_empty?(Map.get(manifest.extra || %{}, "canonical_url")) -> Map.get(manifest.extra, "canonical_url")
        true -> Beacon.RuntimeRenderer.public_page_url(site, %{path: manifest.path})
      end

    assigns = assign(assigns, :canonical_url, canonical_url)

    ~H"""
    <link :if={@canonical_url} rel="canonical" href={@canonical_url} />
    """
  end

  def render_canonical_link(assigns), do: ~H""

  @doc """
  Renders the `<meta name="robots">` tag if configured for the current page.

  Only emits the tag when explicitly set via `extra["robots"]`. Absence means
  the browser/crawler default of "index, follow".
  """
  def render_robots_meta(%{beacon: %{site: site, private: %{page_id: page_id}}} = assigns) do
    manifest = Beacon.RuntimeRenderer.fetch_manifest!(site, page_id)
    robots = manifest[:robots] || Map.get(manifest.extra || %{}, "robots")
    assigns = assign(assigns, :robots, robots)

    ~H"""
    <meta :if={@robots} name="robots" content={@robots} />
    """
  end

  def render_robots_meta(assigns), do: ~H""

  @doc """
  Renders the Schema.org data defined in the current page.

  Values in raw_schema support snippet interpolation (`{{ page.title }}`, etc.).
  """
  def render_schema(%{beacon: %{site: site, private: %{page_id: page_id, layout_id: layout_id}}} = assigns) do
    manifest = Beacon.RuntimeRenderer.fetch_manifest!(site, page_id)
    layout_manifest = case Beacon.RuntimeRenderer.fetch_layout_manifest(site, layout_id) do
      {:ok, lm} -> lm
      :error -> %{}
    end
    config = Beacon.Config.fetch!(site)

    # Manual raw_schema from the page
    manual_schema = manifest.raw_schema || []
    is_empty = fn rs -> rs |> Enum.map(&Map.values/1) |> List.flatten() == [] end
    manual_schema = if is_empty.(manual_schema), do: [], else: manual_schema

    # Interpolate manual schemas
    page_assigns = %{site: site, id: page_id, path: manifest.path, title: manifest.title, description: manifest.description}
    manual_schema = interpolate_raw_schema(manual_schema, page_assigns, assigns)

    # Auto-generate JSON-LD from page metadata
    auto_schema = Beacon.SEO.JsonLd.build(manifest, layout_manifest, config)

    # Merge: manual wins over auto for same @type
    combined = Beacon.SEO.JsonLd.merge(auto_schema, manual_schema)

    if combined == [] do
      []
    else
      assigns = assign(assigns, :raw_schema, Jason.encode!(combined))

      ~H"""
      <script type="application/ld+json">
        <%= {:safe, @raw_schema} %>
      </script>
      """
    end
  end

  @doc """
  Renders all resource `<link>` tags defined in the current layout.
  """
  def render_resource_links(assigns) do
    resource_links =
      case assigns do
        %{beacon: %{site: site, private: %{layout_id: layout_id}}} ->
          case Beacon.RuntimeRenderer.fetch_layout_manifest(site, layout_id) do
            {:ok, manifest} -> manifest.resource_links || []
            :error -> []
          end

        _ ->
          []
      end

    assigns = assign(assigns, :resource_links, resource_links)

    ~H"""
    <%= for attr <- @resource_links do %>
      <link {attr} />
    <% end %>
    """
  end

  @doc """
  Renders `<link rel="prev">` and `<link rel="next">` tags for paginated pages.

  Pages set these via `extra["pagination_prev"]` and `extra["pagination_next"]`.
  """
  def render_pagination_links(%{beacon: %{site: site, private: %{page_id: page_id}}} = assigns) do
    manifest = Beacon.RuntimeRenderer.fetch_manifest!(site, page_id)
    extra = manifest.extra || %{}
    assigns = assign(assigns, :pagination_prev, extra["pagination_prev"])
    assigns = assign(assigns, :pagination_next, extra["pagination_next"])

    ~H"""
    <link :if={@pagination_prev} rel="prev" href={@pagination_prev} />
    <link :if={@pagination_next} rel="next" href={@pagination_next} />
    """
  end

  def render_pagination_links(assigns), do: ~H""

  @doc """
  Renders RSS/Atom feed `<link>` tags from site configuration.

  Configure feeds in the site config:

      feeds: [
        %{url: "/feed.xml", title: "Blog", type: "application/rss+xml"}
      ]
  """
  def render_feed_links(%{beacon: %{site: site}} = assigns) do
    feeds = Map.get(Beacon.Config.fetch!(site), :feeds, [])
    assigns = assign(assigns, :feeds, feeds)

    ~H"""
    <%= for feed <- @feeds do %>
      <link rel="alternate" type={feed.type || feed["type"] || "application/rss+xml"} title={feed.title || feed["title"]} href={feed.url || feed["url"]} />
    <% end %>
    """
  end

  def render_feed_links(assigns), do: ~H""

  # -- Raw schema interpolation --

  defp interpolate_raw_schema(data, page_assigns, assigns) when is_list(data) do
    Enum.map(data, &interpolate_raw_schema(&1, page_assigns, assigns))
  end

  defp interpolate_raw_schema(data, page_assigns, assigns) when is_map(data) do
    Map.new(data, fn {key, value} ->
      {key, interpolate_raw_schema(value, page_assigns, assigns)}
    end)
  end

  defp interpolate_raw_schema(value, page_assigns, assigns) when is_binary(value) do
    case Beacon.Content.render_snippet(value, %{page: page_assigns, data: assigns}) do
      {:ok, rendered} -> rendered
      {:error, _} -> value
    end
  end

  defp interpolate_raw_schema(value, _page_assigns, _assigns), do: value
end
