defmodule BeaconWeb.PageLive do
  use BeaconWeb, :live_view
  use Phoenix.HTML
  require Logger
  import Phoenix.Component
  alias Beacon.Lifecycle

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
    {{site, path}, {page_id, _layout_id, format, page_module, _component_module}} = lookup_route!(assigns.__site__, assigns.__live_path__)
    assigns = Phoenix.Component.assign(assigns, :beacon_path_params, Beacon.Router.path_params(path, assigns.__live_path__))
    page = %Beacon.Content.Page{id: page_id, site: site, path: path, format: format}
    Lifecycle.Template.render_template(page, page_module, assigns, __ENV__)
  end

  defp lookup_route!(site, path) do
    Beacon.Router.lookup_path(site, path) ||
      raise BeaconWeb.NotFoundError, """
      route not found for path #{inspect(path)}

      Make sure a page was created for that path.
      """
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

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  def handle_event(event_name, event_params, socket) do
    socket.assigns.__beacon_page_module__
    |> Beacon.Loader.call_function_with_retry(
      :handle_event,
      [event_name, event_params, socket]
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

    data_source_module = Beacon.Loader.data_source_module_for_site(site)
    live_data = data_source_module.live_data(path, Map.drop(params, ["path"]))
    {{_site, beacon_page_path}, {page_id, layout_id, _format, page_module, component_module}} = lookup_route!(site, path)

    Process.put(:__beacon_site__, site)
    Process.put(:__beacon_page_path__, beacon_page_path)

    socket =
      socket
      |> assign(:beacon_live_data, live_data)
      |> assign(:__live_path__, path)
      |> assign(:__page_updated_at, DateTime.utc_now())
      |> assign(:__dynamic_layout_id__, layout_id)
      |> assign(:__dynamic_page_id__, page_id)
      |> assign(:__site__, site)
      |> assign(:__beacon_page_module__, page_module)
      |> assign(:__beacon_component_module__, component_module)
      |> assign(:__beacon_page_params__, params)

    socket =
      socket
      |> assign(:page_title, BeaconWeb.DataSource.page_title(socket.assigns))
      |> push_event("beacon:page-updated", %{meta_tags: BeaconWeb.DataSource.meta_tags(socket.assigns)})

    {:noreply, socket}
  end

  @doc false
  def make_env, do: __ENV__
end
