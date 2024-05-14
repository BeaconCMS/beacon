defmodule BeaconWeb.PageLive do
  use BeaconWeb, :live_view
  require Logger
  import Phoenix.Component, except: [assign: 2, assign: 3, assign_new: 3], warn: false
  import BeaconWeb, only: [assign: 2, assign: 3, assign_new: 3], warn: false
  alias Beacon.Lifecycle
  alias Beacon.RouterServer
  alias BeaconWeb.BeaconAssigns
  alias Phoenix.Component

  def mount(:not_mounted_at_router, _params, socket) do
    {:ok, socket}
  end

  def mount(params, session, socket) do
    %{"path" => path} = params
    %{"beacon_site" => site} = session

    socket =
      socket
      |> Component.assign(:beacon, %BeaconAssigns{})
      |> BeaconAssigns.update(:site, site)

    if connected?(socket), do: :ok = Beacon.PubSub.subscribe_to_page(site, path)

    {:ok, socket, layout: {BeaconWeb.Layouts, :dynamic}}
  end

  def render(assigns) do
    site = assigns.beacon.site
    live_path = assigns.beacon.private.live_path

    page = RouterServer.lookup_page!(site, live_path)
    path_params = Beacon.Router.path_params(page.path, live_path)

    assigns =
      assigns
      # TODO: remove deprecated @beacon_path_params
      |> Component.assign(:beacon_path_params, path_params)
      |> BeaconAssigns.update(:path_params, path_params)

    Lifecycle.Template.render_template(page, assigns, __ENV__)
  end

  def handle_info({:page_loaded, _}, socket) do
    # TODO: disable automatic template reload (repaint) in favor of https://github.com/BeaconCMS/beacon/issues/179

    socket =
      socket
      # |> BeaconAssigns.update_private(:page_updated_at, DateTime.utc_now())
      # |> assign(:page_title, page_title(params, socket.assigns))
      |> push_event("beacon:page-updated", %{
        meta_tags: BeaconWeb.DataSource.meta_tags(socket.assigns)
        # runtime_css_path: BeaconWeb.Layouts.asset_path(socket, :css)
      })

    {:noreply, socket}
  end

  def handle_info(msg, socket) do
    Logger.warning("""
    unhandled message:

      #{inspect(msg)}

    """)

    {:noreply, socket}
  end

  def handle_event(event_name, event_params, socket) do
    site = socket.assigns.beacon.site
    private = socket.assigns.beacon.private

    private.page_module
    |> Beacon.apply_mfa(:handle_event, [event_name, event_params, socket],
      context: %{site: site, page_id: private[:page_id], page_path: private[:live_path]}
    )
    |> case do
      {:noreply, %Phoenix.LiveView.Socket{} = socket} ->
        {:noreply, socket}

      other ->
        raise "handle_event for #{private[:live_path]} expected return of {:noreply, %Phoenix.LiveView.Socket{}}, but got #{inspect(other)}"
    end
  end

  def handle_params(params, _url, socket) do
    %{"path" => path} = params
    site = socket.assigns.beacon.site

    page = RouterServer.lookup_page!(site, path)
    live_data = BeaconWeb.DataSource.live_data(site, path, Map.drop(params, ["path"]))
    components_module = Beacon.Loader.Components.module_name(site)
    page_module = Beacon.Loader.Page.module_name(site, page.id)
    page_title = BeaconWeb.DataSource.page_title(site, page.id, live_data)

    Process.put(:__beacon_site__, site)
    Process.put(:__beacon_page_path__, page.path)

    socket =
      socket
      |> Component.assign(:beacon_live_data, live_data)
      |> Component.assign(:page_title, page_title)
      |> BeaconAssigns.update_private(:live_path, path)
      |> BeaconAssigns.update_private(:layout_id, page.layout_id)
      |> BeaconAssigns.update_private(:page_id, page.id)
      |> BeaconAssigns.update_private(:page_updated_at, DateTime.utc_now())
      |> BeaconAssigns.update_private(:page_module, page_module)
      |> BeaconAssigns.update_private(:components_module, components_module)
      |> BeaconAssigns.update(:query_params, params)
      |> BeaconAssigns.update(:page, %{title: page_title})
      # TODO: remove deprecated @beacon_query_params
      |> Component.assign(:beacon_query_params, params)

    {:noreply, push_event(socket, "beacon:page-updated", %{meta_tags: BeaconWeb.DataSource.meta_tags(socket.assigns)})}
  end

  @doc false
  def make_env, do: __ENV__
end
