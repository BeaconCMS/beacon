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

    socket = Component.assign(socket, :beacon, BeaconAssigns.build(site))

    if connected?(socket), do: :ok = Beacon.PubSub.subscribe_to_page(site, path)

    {:ok, socket, layout: {BeaconWeb.Layouts, :dynamic}}
  end

  def render(assigns) do
    %{beacon: %{site: site, private: %{live_path: live_path}}} = assigns

    site
    |> RouterServer.lookup_page!(live_path)
    |> Lifecycle.Template.render_template(assigns, __ENV__)
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
    %{beacon: %{site: site, private: %{page_id: page_id, page_module: page_module, live_path: live_path}}} = socket.assigns

    result =
      Beacon.apply_mfa(page_module, :handle_event, [event_name, event_params, socket], context: %{site: site, page_id: page_id, live_path: live_path})

    case result do
      {:noreply, %Phoenix.LiveView.Socket{} = socket} ->
        {:noreply, socket}

      other ->
        raise BeaconWeb.ServerError,
              "handle_event for #{live_path} expected return of {:noreply, %Phoenix.LiveView.Socket{}}, but got #{inspect(other)}"
    end
  end

  def handle_params(params, _url, socket) do
    %{"path" => path_info} = params

    %{site: site, page: page, path_params: path_params, query_params: query_params} =
      beacon_assigns = BeaconAssigns.build(socket.assigns.beacon, path_info, params)

    live_data = BeaconWeb.DataSource.live_data(site, path_info, Map.drop(params, ["path"]))

    Process.put(:__beacon_site__, site)
    Process.put(:__beacon_page_path__, page.path)

    socket =
      socket
      |> Component.assign(:page_title, page.title)
      |> Component.assign(live_data)
      # TODO: remove deprecated @beacon_live_data
      |> Component.assign(:beacon_live_data, live_data)
      # TODO: remove deprecated @beacon_path_params
      |> Component.assign(:beacon_path_params, path_params)
      # TODO: remove deprecated @beacon_query_params
      |> Component.assign(:beacon_query_params, query_params)
      |> Component.assign(:beacon, beacon_assigns)

    {:noreply, push_event(socket, "beacon:page-updated", %{meta_tags: BeaconWeb.DataSource.meta_tags(socket.assigns)})}
  end

  @doc false
  def make_env, do: __ENV__
end
