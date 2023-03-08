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

    {{_, _}, {page_id, layout_id, _, _, _}} =
      Beacon.Router.lookup_path(site, path) ||
        raise """
        TODO
        """

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

    socket =
      socket
      |> assign(:page_title, page_title(params, socket.assigns))
      |> push_event("beacon:page-updated", %{meta_tags: meta_tags(params, socket.assigns), lang: "en"})

    Beacon.PubSub.subscribe_page_update(site, path)

    {:ok, socket, layout: {BeaconWeb.Layouts, :dynamic}}
  end

  def render(assigns) do
    start = System.monotonic_time(:microsecond)

    {{_, path}, {_, _, ast, page_module, component_module}} =
      Beacon.Router.lookup_path(assigns.__site__, assigns.__live_path__) ||
        raise """
        Route not found for path #{inspect(assigns.__live_path__)}

        Make sure a page was created for that path.
        """

    # TODO: beacon_path_params
    assigns = Phoenix.Component.assign(assigns, :beacon_path_params, %{})

    functions = [
      {page_module, [dynamic_helper: 2]},
      {component_module, [my_component: 2]}
      | __ENV__.functions
    ]

    opts =
      __ENV__
      |> Map.from_struct()
      |> Keyword.new()
      |> Keyword.put(:functions, functions)

    {result, _bindings} = Code.eval_quoted(ast, [assigns: assigns], opts)

    Logger.info("[PageLive.render] path: #{path} - time: #{System.monotonic_time(:microsecond) - start} microsecond")

    result
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
