defmodule BeaconWeb.PageLive do
  use BeaconWeb, :live_view_dynamic

  require Logger

  def mount(%{"path" => path} = params, %{"beacon_site" => site}, socket) do
    new_params = Map.drop(params, ["path"])
    {path, path_params} = Beacon.PathParser.parse(site, path, new_params)
    live_data = Beacon.DataSource.live_data(site, path, Map.put(new_params, "path_params", path_params))

    layout_id =
      site
      |> Beacon.Loader.page_module_for_site()
      |> Beacon.Loader.call_function_with_retry(:layout_id_for_path, [path])

    socket =
      socket
      |> assign(:__live_path__, path)
      |> assign(:__live_data__, live_data)
      |> assign(:__page_update_available__, false)
      |> assign(:__dynamic_layout_id__, layout_id)
      |> assign(:__site__, site)

    socket =
      socket
      |> push_event("meta", %{meta: BeaconWeb.LayoutView.meta_tags_unsafe(socket.assigns)})
      |> push_event("lang", %{lang: "en"})

    Beacon.PubSub.subscribe_page_update(site, path)

    {:ok, socket}
  end

  def render(assigns) do
    {%{__live_path__: live_path, __live_data__: live_data}, render_assigns} =
      Map.split(assigns, [:__live_path__, :__live_data__])

    module = Beacon.Loader.page_module_for_site(assigns.__site__)

    Beacon.Loader.call_function_with_retry(module, :render, [live_path, live_data, render_assigns])
  end

  def handle_info(:page_updated, socket) do
    {:noreply, assign(socket, :__page_update_available__, true)}
  end
end
