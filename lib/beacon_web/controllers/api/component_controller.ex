defmodule BeaconWeb.API.ComponentController do
  use BeaconWeb, :controller
  alias Beacon.Content
  alias Beacon.Content.Component

  action_fallback BeaconWeb.API.FallbackController

  def index(conn, %{"site" => site}) do
    # TODO: pagination
    components = Content.list_components(site, per_page: :infinity)
    render(conn, :index, components: components)
  end

  def show(conn, %{"id" => id}) do
    with %Component{} = component <- Content.get_component(id) do
      render(conn, :show, component: component)
    end
  end
end
