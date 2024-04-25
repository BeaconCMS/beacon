defmodule BeaconWeb.PageLive do
  use BeaconWeb, :live_view
  require Logger
  import Phoenix.Component
  alias Beacon.Lifecycle
  alias Beacon.RouterServer

  def mount(:not_mounted_at_router, _params, socket) do
    {:ok, socket}
  end

  def mount(params, session, socket) do
    %{"path" => path} = params
    %{"beacon_site" => site} = session

    socket =
      socket
      |> assign(:beacon, %{site: site})
      |> assign(:__site__, site)

    if connected?(socket), do: :ok = Beacon.PubSub.subscribe_to_page(site, path)

    {:ok, socket, layout: {BeaconWeb.Layouts, :dynamic}}
  end

  def render(assigns) do
    %{__site__: site, __live_path__: live_path} = assigns
    page = RouterServer.lookup_page!(site, live_path)
    assigns = Phoenix.Component.assign(assigns, :beacon_path_params, Beacon.Router.path_params(page.path, live_path))
    Lifecycle.Template.render_template(page, assigns, __ENV__)
  end

  def handle_info({:page_loaded, _}, socket) do
    # TODO: disable automatic template reload (repaint) in favor of https://github.com/BeaconCMS/beacon/issues/179

    socket =
      socket
      # |> assign(:__page_updated_at, DateTime.utc_now())
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
    socket.assigns.__beacon_page_module__
    |> Beacon.apply_mfa(:handle_event, [event_name, event_params, socket],
      context: %{site: socket.assigns[:__site__], page_id: socket.assigns[:__dynamic_page_id__], page_path: socket.assigns[:__live_path__]}
    )
    |> case do
      {:noreply, %Phoenix.LiveView.Socket{} = socket} ->
        {:noreply, socket}

      other ->
        raise "handle_event for #{socket.assigns.__live_path__} expected return of {:noreply, %Phoenix.LiveView.Socket{}}, but got #{inspect(other)}"
    end
  end

  def handle_params(params, _url, socket) do
    %{"path" => path} = params
    %{__site__: site} = socket.assigns

    page = RouterServer.lookup_page!(site, path)
    live_data = BeaconWeb.DataSource.live_data(site, path, Map.drop(params, ["path"]))

    components_module = Beacon.Loader.Components.module_name(site)
    page_module = Beacon.Loader.Page.module_name(site, page.id)

    Process.put(:__beacon_site__, site)
    Process.put(:__beacon_page_path__, page.path)

    socket =
      socket
      |> assign(:beacon_live_data, live_data)
      |> assign(:__live_path__, path)
      |> assign(:__page_updated_at, DateTime.utc_now())
      |> assign(:__dynamic_layout_id__, page.layout_id)
      |> assign(:__dynamic_page_id__, page.id)
      |> assign(:__site__, site)
      |> assign(:__beacon_page_module__, page_module)
      |> assign(:__beacon_component_module__, components_module)
      |> assign(:beacon_query_params, params)

    socket =
      socket
      |> assign(:page_title, BeaconWeb.DataSource.page_title(site, page.id, live_data))
      |> push_event("beacon:page-updated", %{meta_tags: BeaconWeb.DataSource.meta_tags(socket.assigns)})

    {:noreply, socket}
  end

  @doc false
  def make_env, do: __ENV__
end
