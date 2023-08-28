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

  def show(conn, %{"site" => site, "id" => id}) do
    site = String.to_existing_atom(site)

    with %Component{} = component <- Content.get_component_by(site, id: id) do
      render(conn, :show, component: component, site: site)
    end
  end
end
