defmodule Beacon.RuntimeRenderer.Loader do
  @moduledoc """
  Loads published content from the database into the RuntimeRenderer's ETS store.

  This replaces the Beacon.Loader / Beacon.Loader.Worker / Beacon.ErrorHandler
  pipeline. Instead of compiling content into BEAM modules, it transforms
  content into serializable IR and stores it in ETS.

  Called at boot time to warm the cache, and on publish events to update it.
  """

  alias Beacon.Content
  alias Beacon.RuntimeRenderer

  @doc """
  Loads all published content for a site from the database into ETS.
  Called during site boot.
  """
  def load_site(site) when is_atom(site) do
    RuntimeRenderer.init()

    load_components(site)
    load_layouts(site)
    load_event_handlers(site)
    load_info_handlers(site)
    load_error_pages(site)
    load_snippet_helpers(site)

    # Pages load lazily on first request — we don't deserialize page binaries
    # at boot. But we DO load the route index (path → page_id) so dynamic
    # route matching works from ETS without querying the DB on every request.
    load_route_index(site)

    # Load redirects into ETS for fast request-path lookups
    Beacon.Content.RedirectCache.load_redirects(site)

    :ok
  end

  @doc """
  Loads the route index (path → page_id) for all published pages into ETS.
  This is lightweight — only path strings and UUIDs, no page binary deserialization.
  Enables dynamic route matching (e.g., /blog/authors/:slug) from ETS at request time.
  """
  def load_route_index(site) do
    paths = Content.list_published_page_paths(site)

    for {page_id, path} <- paths do
      RuntimeRenderer.register_route(site, page_id, path)
    end

    require Logger
    Logger.info("[Beacon.RuntimeRenderer] Loaded #{length(paths)} routes for site #{site}")
  end

  @doc """
  Loads all published pages for a site into the RuntimeRenderer.
  """
  def load_pages(site) do
    # Bulk-load all published pages from snapshots in a single query.
    # This avoids the N+1 reload+preload in list_published_pages.
    pages = Content.list_published_pages_snapshot_data(site)

    results =
      Enum.map(pages, fn page ->
        try do
          load_page(site, page)
          :ok
        rescue
          error ->
            require Logger
            Logger.warning("[Beacon.RuntimeRenderer] Skipped page #{page.path} (#{page.format}): #{Exception.message(error)}")
            :error
        end
      end)

    loaded = Enum.count(results, &(&1 == :ok))
    skipped = Enum.count(results, &(&1 == :error))

    require Logger
    Logger.info("[Beacon.RuntimeRenderer] Loaded #{loaded} pages, skipped #{skipped} for site #{site}")
  end

  @doc """
  Loads a single published page into the RuntimeRenderer.
  Called at boot and when a page is published.
  """
  def load_page(site, %{} = page) do
    page_id = page.id

    # Merge snapshot-level extra into page extra
    # with the page-level extra (from the deserialized binary).
    # Snapshot extra is the source of truth for fields added after publication.
    page = merge_snapshot_extra(site, page)

    # Run lifecycle hooks to transform the template (e.g., markdown → HTML)
    # This is the same step the current Loader.Page does before HEEx compilation.
    template = Beacon.Lifecycle.Template.load_template(page)

    # Extract helpers from page (may need preloading)
    helpers =
      case Map.get(page, :helpers) do
        nil -> []
        helpers when is_list(helpers) ->
          Enum.map(helpers, fn h ->
            %{name: h.name, args: h.args, code: h.code}
          end)
      end

    # Use pre-computed AST from snapshot/page if available
    pre_computed_ast = Map.get(page, :ast)

    RuntimeRenderer.publish_page(site, page_id, %{
      template: template,
      path: page.path,
      title: page.title,
      description: page.description || "",
      format: page.format,
      layout_id: to_string(page.layout_id),
      extra: page.extra || %{},
      meta_tags: page.meta_tags || [],
      raw_schema: page.raw_schema || [],
      meta_description: Map.get(page, :meta_description),
      canonical_url: Map.get(page, :canonical_url),
      robots: Map.get(page, :robots),
      og_title: Map.get(page, :og_title),
      og_description: Map.get(page, :og_description),
      og_image: Map.get(page, :og_image),
      twitter_card: Map.get(page, :twitter_card),
      date_modified: Map.get(page, :date_modified),
      collection_id: Map.get(page, :collection_id),
      collection: resolve_collection(site, Map.get(page, :collection_id)),
      fields: Map.get(page, :fields, %{}),
      inserted_at: Map.get(page, :inserted_at),
      updated_at: Map.get(page, :updated_at),
      assigns: %{},
      event_handlers: [],
      helpers: helpers,
      ast: pre_computed_ast
    })
  end

  defp resolve_collection(_site, nil), do: nil
  defp resolve_collection(site, collection_id) do
    case Content.get_collection(site, collection_id) do
      nil -> nil
      col -> %{
        name: col.name,
        slug: col.slug,
        mode: col.mode,
        fields: col.fields,
        json_ld_mapping: col.json_ld_mapping,
        meta_tag_mapping: col.meta_tag_mapping
      }
    end
  end

  @doc """
  Loads all components for a site into the RuntimeRenderer.
  """
  def load_components(site) do
    components = Content.list_components(site, per_page: :infinity)

    results =
      Enum.map(components, fn component ->
        try do
          component_attrs = component.attrs || []
          attrs_list = Enum.map(component_attrs, fn a -> %{name: a.name, opts: a.opts || []} end)
          RuntimeRenderer.publish_component(site, component.name, component.template, component.body || "", attrs: attrs_list)
          :ok
        rescue
          error ->
            require Logger
            Logger.warning("[Beacon.RuntimeRenderer] Skipped component #{component.name}: #{Exception.message(error)}")
            :error
        end
      end)

    loaded = Enum.count(results, &(&1 == :ok))
    skipped = Enum.count(results, &(&1 == :error))

    require Logger
    Logger.info("[Beacon.RuntimeRenderer] Loaded #{loaded} components, skipped #{skipped} for site #{site}")
  end

  @doc """
  Loads all published layouts for a site into the RuntimeRenderer.
  """
  def load_layouts(site) do
    layouts = Content.list_published_layouts(site) |> Enum.reject(&is_nil/1)

    for layout <- layouts do
      RuntimeRenderer.publish_layout(site, to_string(layout.id), layout.template,
        meta_tags: layout.meta_tags || [],
        resource_links: layout.resource_links || [],
        default_og_image: Map.get(layout, :default_og_image),
        default_twitter_card: Map.get(layout, :default_twitter_card)
      )
    end

    require Logger
    Logger.info("[Beacon.RuntimeRenderer] Loaded #{length(layouts)} layouts for site #{site}")
  end

  @doc """
  Loads event handlers for a site into the RuntimeRenderer.
  Event handlers are global per-site (not per-page), so they're stored
  against a sentinel page_id.
  """
  def load_event_handlers(site) do
    handlers = Content.list_event_handlers(site)

    for handler <- handlers do
      case handler.format do
        :actions when is_map(handler.actions) ->
          RuntimeRenderer.store_site_handler_actions(site, :event, handler.name, handler.actions)

        _ ->
          # Default to :elixir format (backward compatible)
          RuntimeRenderer.store_site_handler(site, :event, handler.name, handler.code)
      end
    end

    require Logger
    Logger.info("[Beacon.RuntimeRenderer] Loaded #{length(handlers)} event handlers for site #{site}")
  end

  @doc """
  Loads info handlers for a site into the RuntimeRenderer.
  """
  def load_info_handlers(site) do
    handlers = Content.list_info_handlers(site)

    for handler <- handlers do
      RuntimeRenderer.store_site_handler(site, :info, handler.msg, handler.code)
    end

    require Logger
    Logger.info("[Beacon.RuntimeRenderer] Loaded #{length(handlers)} info handlers for site #{site}")
  end

  @doc """
  Reloads a single page after it's been published.
  Called from PubSub handler.
  """
  def reload_page(site, page_id) do
    # Clear the Content-level cache so we fetch the NEWLY published
    # snapshot, not the stale cached version.
    Content.clear_page_cache(site, page_id)

    case Content.get_published_page(site, page_id) do
      nil ->
        # Page was unpublished
        RuntimeRenderer.unpublish_page(site, page_id)

      page ->
        load_page(site, page)
    end
  end

  @doc """
  Reloads all event handlers for a site.
  Called when handlers are updated.
  """
  def reload_event_handlers(site) do
    load_event_handlers(site)
  end

  @doc """
  Loads all error pages for a site into the RuntimeRenderer.
  """
  def load_error_pages(site) do
    error_pages = Content.list_error_pages(site, per_page: :infinity)

    results =
      Enum.map(error_pages, fn error_page ->
        try do
          RuntimeRenderer.publish_error_page(site, error_page.status, error_page.template)
          :ok
        rescue
          error ->
            require Logger
            Logger.warning("[Beacon.RuntimeRenderer] Skipped error page #{error_page.status}: #{Exception.message(error)}")
            :error
        end
      end)

    loaded = Enum.count(results, &(&1 == :ok))
    skipped = Enum.count(results, &(&1 == :error))

    require Logger
    Logger.info("[Beacon.RuntimeRenderer] Loaded #{loaded} error pages, skipped #{skipped} for site #{site}")
  end

  @doc """
  Loads all snippet helpers for a site into the RuntimeRenderer.
  """
  def load_snippet_helpers(site) do
    helpers = Content.list_snippet_helpers(site)

    for helper <- helpers do
      RuntimeRenderer.publish_snippet_helper(site, helper.name, helper.body)
    end

    require Logger
    Logger.info("[Beacon.RuntimeRenderer] Loaded #{length(helpers)} snippet helpers for site #{site}")
  end

  @doc """
  Reloads a single layout after it's been published.
  Fetches the layout from the database and publishes it to ETS.
  """
  def reload_layout(site, layout_id) do
    layout_id = to_string(layout_id)
    Content.clear_page_cache(site, layout_id)

    case Content.get_published_layout(site, layout_id) do
      nil ->
        require Logger
        Logger.warning("[Beacon.RuntimeRenderer] Layout #{layout_id} not found for site #{site}")
        :error

      layout ->
        RuntimeRenderer.publish_layout(site, to_string(layout.id), layout.template,
          meta_tags: layout.meta_tags || [],
          resource_links: layout.resource_links || [],
          default_og_image: Map.get(layout, :default_og_image),
          default_twitter_card: Map.get(layout, :default_twitter_card)
        )
    end
  end

  @doc """
  Reloads a single component after it's been updated.
  Fetches the component from the database and publishes it to ETS.
  """
  def reload_component(site, component_name) do
    case Content.get_component_by(site, name: component_name) do
      nil ->
        require Logger
        Logger.warning("[Beacon.RuntimeRenderer] Component #{component_name} not found for site #{site}")
        :error

      component ->
        component_attrs = (component.attrs || [])
        attrs_list = Enum.map(component_attrs, fn a -> %{name: a.name, opts: a.opts || []} end)
        RuntimeRenderer.publish_component(site, component.name, component.template, component.body || "", attrs: attrs_list)
    end
  end

  @doc """
  Reloads all snippet helpers for a site.
  Called when snippet helpers are updated.
  """
  def reload_snippets(site) do
    load_snippet_helpers(site)
  end

  @doc """
  Reloads all error pages for a site.
  Called when error pages are updated.
  """
  def reload_error_pages(site) do
    load_error_pages(site)
  end

  @doc """
  Reloads all info handlers for a site.
  Called when info handlers are updated.
  """
  def reload_info_handlers(site) do
    load_info_handlers(site)
  end

  # Merge the snapshot-level extra column into the page struct's extra.
  # Snapshot extra may contain fields added after publication.
  defp merge_snapshot_extra(site, page) do
    import Ecto.Query

    snapshot_extra =
      try do
        Beacon.Utils.repo(site).one(
          from(s in "beacon_page_snapshots",
            where: s.path == ^page.path and s.site == ^to_string(site),
            order_by: [desc: s.inserted_at],
            limit: 1,
            select: s.extra
          )
        )
      rescue
        _ -> nil
      end

    case snapshot_extra do
      extra when is_map(extra) and extra != %{} ->
        updated_extra = Map.merge(page.extra || %{}, extra)
        %{page | extra: updated_extra}

      _ ->
        page
    end
  end

end
