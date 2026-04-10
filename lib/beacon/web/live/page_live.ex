defmodule Beacon.Web.PageLive do
  @moduledoc false

  use Beacon.Web, :live_view
  require Logger
  import Phoenix.Component, except: [assign: 2, assign: 3, assign_new: 3], warn: false
  import Beacon.Web, only: [assign: 2, assign: 3, assign_new: 3], warn: false
  alias Phoenix.Component

  def mount(:not_mounted_at_router, _params, socket) do
    {:ok, socket}
  end

  def mount(params, session, socket) do
    %{"path" => path} = params
    %{"beacon_site" => site} = session
    config = Beacon.Config.fetch!(site)

    if config.mode == :live and connected?(socket) do
      :ok = Beacon.PubSub.subscribe_to_page(site, path)
    end

    variant_roll =
      case session["beacon_variant_roll"] do
        nil ->
          Logger.warning("""
          Beacon.Plug is missing from the Router pipeline.

          Page Variants will not be used.
          """)

          nil

        roll ->
          roll
      end

    # Check if CSS is ready before blocking on page rendering
    warming = not Beacon.RuntimeCSS.css_ready?(site)

    if warming do
      Beacon.RuntimeCSS.compile_async(site)

      if connected?(socket) do
        Beacon.PubSub.subscribe_to_css(site)
      end
    end

    path_str = "/" <> Enum.join(path, "/")
    {:ok, assigns} = Beacon.RuntimeRenderer.mount_assigns(site, path_str, variant_roll: variant_roll)

    # Subscribe to DataStore invalidation topics for this page's data sources
    if config.mode == :live and connected?(socket) do
      for source_name <- Map.get(assigns.beacon.private, :data_source_names, []) do
        Beacon.DataStore.subscribe(site, source_name)
      end
    end

    socket =
      socket
      |> Component.assign(assigns)
      |> Component.assign(:beacon_warming, warming)

    {:ok, socket, layout: {Beacon.Web.Layouts, :dynamic}}
  end

  def render(%{beacon_warming: true} = assigns) do
    %{beacon: %{site: site}} = assigns
    warming_html = Beacon.Web.Warming.render(site)

    assigns = Map.put(assigns, :warming_html, warming_html)

    ~H"""
    <%= {:safe, @warming_html} %>
    """
  end

  def render(assigns) do
    %{beacon: %{site: site, private: %{page_id: page_id}}} = assigns
    {:ok, rendered} = Beacon.RuntimeRenderer.render_page(site, page_id, assigns)
    rendered
  end

  def handle_info({:css_compiled, site}, socket) do
    %{beacon: %{site: socket_site}} = socket.assigns

    if site == socket_site do
      # Redirect (not push_navigate) to force a full HTTP request.
      # push_navigate keeps the existing root layout, so the <link href="css-warming">
      # tag would persist. A redirect re-renders the root layout with the real CSS hash.
      path = socket.assigns.beacon.private.live_path
      {:noreply, redirect(socket, to: "/" <> Enum.join(path, "/"))}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:beacon_data_store_invalidated, source_name}, socket) do
    %{beacon: %{site: site, private: %{page_id: page_id}}} = socket.assigns

    # Re-fetch the invalidated data source with current params
    case Beacon.RuntimeRenderer.fetch_manifest(site, page_id) do
      {:ok, manifest} ->
        path_params = socket.assigns.beacon.path_params
        query_params = socket.assigns.beacon.query_params
        specs = Map.get(manifest.extra, "data_sources", [])

        spec = Enum.find(specs, fn s ->
          name = s["source"] || s[:source]
          to_string(name) == to_string(source_name)
        end)

        if spec do
          raw_params = spec["params"] || spec[:params] || %{}
          resolved = Beacon.RuntimeRenderer.resolve_data_store_params(raw_params, path_params, query_params)
          value = Beacon.DataStore.fetch(site, source_name, resolved)
          {:noreply, Component.assign(socket, source_name, value)}
        else
          {:noreply, socket}
        end

      :error ->
        {:noreply, socket}
    end
  end

  def handle_info({:beacon_data_store_invalidated, source_name, _params}, socket) do
    # Re-fetch with current params regardless of which specific params were invalidated
    handle_info({:beacon_data_store_invalidated, source_name}, socket)
  end

  def handle_info({:page_loaded, _}, socket) do
    # TODO: disable automatic template reload (repaint) in favor of https://github.com/BeaconCMS/beacon/issues/179

    socket =
      socket
      # |> BeaconAssigns.update_private(:page_updated_at, DateTime.utc_now())
      # |> assign(:page_title, page_title(params, socket.assigns))
      |> push_event("beacon:page-updated", %{
        meta_tags: Beacon.Web.DataSource.meta_tags(socket.assigns)
        # runtime_css_path: Beacon.Web.Layouts.asset_path(socket, :css)
      })

    {:noreply, socket}
  end

  def handle_info(msg, socket) do
    %{beacon: %{site: site, private: %{page_id: page_id}}} = socket.assigns

    case Beacon.RuntimeRenderer.handle_site_info(site, msg, socket) do
      {:noreply, %Phoenix.LiveView.Socket{} = socket} ->
        {:noreply, socket}

      {:error, {:no_handler, _}} ->
        Logger.warning("[Beacon] No info handler for message #{inspect(msg)} on page #{page_id}")
        {:noreply, socket}

      other ->
        raise Beacon.Web.ServerError,
              "handle_info expected {:noreply, socket}, got #{inspect(other)}"
    end
  end

  def handle_event(event_name, event_params, socket) do
    %{beacon: %{site: site}} = socket.assigns

    case Beacon.RuntimeRenderer.handle_site_event(site, event_name, event_params, socket) do
      {:noreply, %Phoenix.LiveView.Socket{} = socket} ->
        {:noreply, socket}

      {:error, {:no_handler, _}} ->
        {:noreply, socket}

      other ->
        raise Beacon.Web.ServerError,
              "handle_event expected {:noreply, socket}, got #{inspect(other)}"
    end
  end

  def handle_params(params, url, socket) do
    case Beacon.Private.site_from_session(socket.endpoint, socket.router, url, __MODULE__) do
      nil ->
        raise Beacon.Web.NotFoundError, """
        no page found for url #{url}

        Make sure a page was created for that url.
        """

      site ->
        %{"path" => path_info} = params
        path_str = "/" <> Enum.join(path_info, "/")

        if socket.assigns.beacon.site != site && Beacon.Config.fetch!(site).mode == :live do
          Beacon.PubSub.unsubscribe_to_page(socket.assigns.beacon.site, path_info)
          Beacon.PubSub.subscribe_to_page(site, path_info)
        end

        {:ok, params_assigns} = Beacon.RuntimeRenderer.handle_params_assigns(site, path_str, params)

        # Update DataStore subscriptions if navigating to a different page
        old_sources = Map.get(socket.assigns.beacon.private, :data_source_names, [])
        new_sources = Map.get(params_assigns.beacon.private, :data_source_names, [])

        if connected?(socket) do
          for source <- old_sources -- new_sources, do: Beacon.DataStore.unsubscribe(site, source)
          for source <- new_sources -- old_sources, do: Beacon.DataStore.subscribe(site, source)
        end

        socket =
          socket
          |> Component.assign(params_assigns)
          |> Component.assign(:page_title, params_assigns.beacon.page.title)

        {:noreply, socket}
    end
  end

  @doc false
  def make_env(_site) do
    __ENV__
  end

end
