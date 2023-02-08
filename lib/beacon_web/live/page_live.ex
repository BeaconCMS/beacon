defmodule BeaconWeb.PageLive do
  use BeaconWeb, :live_view

  require Logger

  alias Beacon.BeaconAttrs

  def mount(:not_mounted_at_router, _params, socket) do
    {:ok, socket}
  end

  def mount(params, session, socket) do
    %{"path" => path} = params
    %{"beacon_site" => site} = session
    data_source = Beacon.Config.data_source(site)

    Beacon.persist_term({:beacon, site, "data_source"}, data_source)

    live_data = Beacon.DataSource.live_data(site, path, Map.drop(params, ["path"]))

    layout_id =
      site
      |> Beacon.Loader.page_module_for_site()
      |> Beacon.Loader.call_function_with_retry(:layout_id_for_path, [path])

    page_id =
      site
      |> Beacon.Loader.page_module_for_site()
      |> Beacon.Loader.call_function_with_retry(:page_id, [path])

    socket =
      socket
      |> assign(:beacon, %{site: site})
      |> assign(:beacon_live_data, live_data)
      |> assign(:__live_path__, path)
      |> assign(:__page_update_available__, false)
      |> assign(:__dynamic_layout_id__, layout_id)
      |> assign(:__dynamic_page_id__, page_id)
      |> assign(:__site__, site)

    socket =
      socket
      |> push_event("meta", %{meta: BeaconWeb.Layouts.layout_meta_tags_unsafe(socket.assigns)})
      |> push_event("lang", %{lang: "en"})

    socket = assign(socket, :beacon_attrs, %BeaconAttrs{router: socket.router})

    Beacon.PubSub.subscribe_page_update(site, path)

    {:ok, socket, layout: {BeaconWeb.Layouts, :dynamic}}
  end

  def render(assigns) do
    {%{__live_path__: live_path}, render_assigns} = Map.split(assigns, [:__live_path__])

    module = Beacon.Loader.page_module_for_site(assigns.__site__)

    Beacon.Loader.call_function_with_retry(module, :render, [live_path, render_assigns])
  end

  def handle_info(:page_updated, socket) do
    {:noreply, assign(socket, :__page_update_available__, true)}
  end

  def handle_event(event_name, event_params, socket) do
    socket.assigns.__site__
    |> Beacon.Loader.page_module_for_site()
    |> Beacon.Loader.call_function_with_retry(
      :handle_event,
      [socket.assigns.__live_path__, event_name, event_params, socket]
    )
    |> case do
      {:noreply, %Phoenix.LiveView.Socket{} = socket} ->
        {:noreply, socket}

      other ->
        raise "handle_event for #{socket.assigns.__live_path__} expected return of {:noreply, %Phoenix.LiveView.Socket{}}, but got #{inspect(other)}"
    end
  end
end
