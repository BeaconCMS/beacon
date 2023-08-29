defmodule BeaconWeb.API.ComponentController do
  use BeaconWeb, :controller
  alias Beacon.Content

  action_fallback BeaconWeb.API.FallbackController

  def index(conn, %{"site" => site}) do
    # TODO: pagination
    components = Content.list_components(site, per_page: :infinity)
    render(conn, :index, components: components)
  end

  def show(conn, %{"component_id" => component_id}) do
    component = Content.get_component!(component_id)
    render(conn, :show, component: component)
  end

  def show_ast(conn, %{"page_id" => page_id, "component_id" => component_id}) do
    page = Content.get_page!(page_id)
    path = for segment <- String.split(page.path, "/"), segment != "", do: segment
    beacon_live_data = Beacon.DataSource.live_data(page.site, path, [])
    component = Content.get_component!(component_id)
    render(conn, :show_ast, component: component, assigns: %{beacon_live_data: beacon_live_data})
  end
end
