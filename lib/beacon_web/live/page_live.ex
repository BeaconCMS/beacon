defmodule BeaconWeb.PageLive do
  use BeaconWeb, :live_view
  use Phoenix.HTML
  require Logger
  import Phoenix.Component
  alias Beacon.BeaconAttrs

  def mount(:not_mounted_at_router, _params, socket) do
    {:ok, socket}
  end

  def mount(params, session, socket) do
    %{"path" => path} = params
    %{"beacon_site" => site} = session

    live_data = Beacon.DataSource.live_data(site, path, Map.drop(params, ["path"]))

    {{_site, _path}, {page_id, layout_id, templat_ast, page_module, component_module}} = lookup_route!(site, path)

    socket =
      socket
      |> assign(:beacon, %{site: site})
      |> assign(:beacon_live_data, live_data)
      |> assign(:beacon_attrs, %BeaconAttrs{router: socket.router})
      |> assign(:__live_path__, path)
      |> assign(:__page_update_available__, false)
      |> assign(:__dynamic_layout_id__, layout_id)
      |> assign(:__dynamic_page_id__, page_id)
      |> assign(:__site__, site)
      |> assign(:__beacon_page_template_ast__, templat_ast)
      |> assign(:__beacon_page_module__, page_module)
      |> assign(:__beacon_component_module__, component_module)

    socket =
      socket
      |> assign(:page_title, page_title(params, socket.assigns))
      |> push_event("beacon:page-updated", %{meta_tags: meta_tags(params, socket.assigns), lang: "en"})

    Beacon.PubSub.subscribe_page_update(site, path)

    {:ok, socket, layout: {BeaconWeb.Layouts, :dynamic}}
  end

  def render(assigns) do
    start = System.monotonic_time(:microsecond)

    {{_site, path}, {_page_id, _layout_id, template_ast, _page_module, _component_module}} = lookup_route!(assigns.__site__, assigns.__live_path__)

    assigns = Phoenix.Component.assign(assigns, :beacon_path_params, path_params(path, assigns.__live_path__))

    functions = [
      {assigns.__beacon_page_module__, [dynamic_helper: 2]},
      {assigns.__beacon_component_module__, [my_component: 2]}
      | __ENV__.functions
    ]

    opts =
      __ENV__
      |> Map.from_struct()
      |> Keyword.new()
      |> Keyword.put(:functions, functions)

    {result, _bindings} = Code.eval_quoted(template_ast, [assigns: assigns], opts)

    Logger.info("[PageLive.render] path: #{inspect(assigns.__live_path__)} - time: #{System.monotonic_time(:microsecond) - start} microsecond")

    result
  end

  defp lookup_route!(site, path) do
    Beacon.Router.lookup_path(site, path) ||
      raise """
      Route not found for path #{inspect(path)}

      Make sure a page was created for that path.
      """
  end

  defp path_params(page_path, path_info) do
    page_path = String.split(page_path, "/")

    Enum.zip_reduce(page_path, path_info, %{}, fn
      ":" <> segment, value, acc ->
        Map.put(acc, segment, value)

      "*" <> segment, value, acc ->
        position = Enum.find_index(path_info, &(&1 == value))
        Map.put(acc, segment, Enum.drop(path_info, position))

      _, _, acc ->
        acc
    end)
  end

  def handle_info(:page_updated, socket) do
    {:noreply, assign(socket, :__page_update_available__, true)}
  end

  def handle_event(event_name, event_params, socket) do
    socket.assigns.__beacon_page_module__
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

  def handle_params(params, _url, socket) do
    socket =
      socket
      |> assign(:page_title, page_title(params, socket.assigns))
      |> push_event("beacon:page-updated", %{meta_tags: meta_tags(params, socket.assigns), lang: "en"})

    {:noreply, socket}
  end

  defp page_title(params, %{__site__: site, __live_path__: path, beacon_live_data: live_data} = assigns) do
    Beacon.DataSource.page_title(site, path, params, live_data, BeaconWeb.Layouts.page_title(assigns))
  end

  defp meta_tags(params, %{__site__: site, __live_path__: path, beacon_live_data: live_data} = assigns) do
    Beacon.DataSource.meta_tags(site, path, params, live_data, BeaconWeb.Layouts.meta_tags(assigns))
  end
end
