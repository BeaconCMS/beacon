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
end
