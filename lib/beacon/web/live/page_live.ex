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

    # Subscribe to GraphQL cache invalidation topics
    if config.mode == :live and connected?(socket) do
      for endpoint_name <- Map.get(assigns.beacon.private, :graphql_endpoint_names, []) do
        Beacon.PubSub.subscribe_to_graphql(site, endpoint_name)
      end
    end

    # Subscribe to page render cache updates
    if config.mode == :live and connected?(socket) do
      path_str = "/" <> Enum.join(path, "/")
      Beacon.PubSub.subscribe_to_page_render(site, path_str)
    end

    socket =
      socket
      |> Component.assign(assigns)
      |> Component.assign(:beacon_warming, warming)
      |> Component.assign(:beacon_update_available, false)

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

    update_available = Map.get(assigns, :beacon_update_available, false)
    if update_available, do: Logger.info("[PageLive] Rendering with update notification")

    if update_available do
      config = Beacon.Config.fetch!(site)

      case config.update_notification_component do
        nil ->
          notification_assigns = Map.put(assigns, :beacon_page_content, rendered)

          case Beacon.RuntimeRenderer.render_site_setting(site, "notification_template", notification_assigns) do
            {:ok, notification_rendered} ->
              assigns =
                assigns
                |> Map.put(:beacon_page_content, rendered)
                |> Map.put(:beacon_notification_rendered, notification_rendered)

              ~H"""
              <%= @beacon_page_content %>
              <%= @beacon_notification_rendered %>
              """

            {:error, :not_found} ->
              assigns = Map.put(assigns, :beacon_page_content, rendered)

              ~H"""
              <%= @beacon_page_content %>
              <div
                id="beacon-update-notification"
                style="position:fixed;bottom:1rem;right:1rem;z-index:9999;background:#1a1a2e;color:white;padding:0.75rem 1.25rem;border-radius:0.5rem;box-shadow:0 4px 12px rgba(0,0,0,0.15);display:flex;align-items:center;gap:0.75rem;font-family:system-ui,sans-serif;font-size:0.875rem;"
              >
                <span>This page has been updated</span>
                <button
                  phx-click="beacon:apply-update"
                  style="background:#4361ee;color:white;border:none;padding:0.375rem 0.75rem;border-radius:0.25rem;cursor:pointer;font-size:0.875rem;"
                >
                  Refresh
                </button>
                <button
                  phx-click="beacon:dismiss-update"
                  style="background:transparent;color:#999;border:none;cursor:pointer;font-size:1rem;padding:0 0.25rem;"
                >
                  &times;
                </button>
              </div>
              """
          end

        custom_mod ->
          assigns =
            assigns
            |> Map.put(:beacon_page_content, rendered)
            |> Map.put(:beacon_notification_component, custom_mod)

          ~H"""
          <%= @beacon_page_content %>
          <%= @beacon_notification_component.render(assigns) %>
          """
      end
    else
      rendered
    end
  end

  def handle_info({:page_render_updated, %{site: msg_site, page_id: _page_id}}, socket) do
    %{beacon: %{site: site}} = socket.assigns
    Logger.info("[PageLive] Received page_render_updated for site #{msg_site}, my site: #{site}")

    if msg_site != site do
      {:noreply, socket}
    else
      config = Beacon.Config.fetch!(site)
      page_type = get_in(socket.assigns, [:beacon, :private, :page_type]) || "default"

      mode = Map.get(config.live_update_overrides, page_type, config.live_update)

      case mode do
        :manual ->
          {:noreply, socket}

        :notify ->
          {:noreply, Component.assign(socket, :beacon_update_available, true)}

        :automatic ->
          do_live_update(socket)
      end
    end
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

  def handle_info({:graphql_cache_invalidated, endpoint_name}, socket) do
    %{beacon: %{site: site, private: %{page_id: page_id}}} = socket.assigns
    path_params = socket.assigns.beacon.path_params
    query_params = socket.assigns.beacon.query_params

    # Re-fetch only the queries for the invalidated endpoint
    page_queries =
      Beacon.Content.list_page_queries(site, page_id)
      |> Enum.filter(&(&1.endpoint_name == endpoint_name))

    if page_queries != [] do
      {new_assigns, _} =
        Beacon.GraphQL.QueryExecutor.execute_page_queries(site, page_queries, path_params, query_params)

      updated_socket =
        Enum.reduce(new_assigns, socket, fn {key, value}, acc ->
          assign_key = if is_binary(key), do: String.to_existing_atom(key), else: key
          Component.assign(acc, assign_key, value)
        end)

      {:noreply, updated_socket}
    else
      {:noreply, socket}
    end
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

  def handle_event("beacon:apply-update", _params, socket) do
    {:noreply, updated_socket} = do_live_update(socket)
    {:noreply, Component.assign(updated_socket, :beacon_update_available, false)}
  end

  def handle_event("beacon:dismiss-update", _params, socket) do
    {:noreply, Component.assign(socket, :beacon_update_available, false)}
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

        # Update GraphQL subscriptions if navigating to a different page
        old_endpoints = Map.get(socket.assigns.beacon.private, :graphql_endpoint_names, [])
        new_endpoints = Map.get(params_assigns.beacon.private, :graphql_endpoint_names, [])

        if connected?(socket) do
          for ep <- old_endpoints -- new_endpoints, do: Beacon.PubSub.unsubscribe_from_graphql(site, ep)
          for ep <- new_endpoints -- old_endpoints, do: Beacon.PubSub.subscribe_to_graphql(site, ep)
        end

        # Update page render cache subscriptions when navigating between pages
        if connected?(socket) do
          old_path = "/" <> Enum.join(socket.assigns.beacon.private.live_path, "/")
          new_path = "/" <> Enum.join(path_info, "/")

          if old_path != new_path do
            Beacon.PubSub.unsubscribe_from_page_render(site, old_path)
            Beacon.PubSub.subscribe_to_page_render(site, new_path)
          end
        end

        socket =
          socket
          |> Component.assign(params_assigns)
          |> Component.assign(:page_title, params_assigns.beacon.page.title)
          |> Component.assign(:beacon_update_available, false)

        {:noreply, socket}
    end
  end

  defp do_live_update(socket) do
    %{beacon: %{site: site, private: %{live_path: path_info}}} = socket.assigns
    path_str = "/" <> Enum.join(path_info, "/")

    # Get current query params from socket
    query_params = socket.assigns.beacon.query_params || %{}
    params = Map.put(query_params, "path", path_info)

    {:ok, assigns} = Beacon.RuntimeRenderer.handle_params_assigns(site, path_str, params)

    socket =
      socket
      |> Component.assign(assigns)
      |> Component.assign(:beacon_update_available, false)

    {:noreply, socket}
  end

  @doc false
  def make_env(_site) do
    __ENV__
  end

end
