defmodule BeaconWeb.API.ComponentController do
  use BeaconWeb, :controller
  alias Beacon.ComponentCategories
  alias Beacon.ComponentDefinitions
  require Logger

  action_fallback BeaconWeb.API.FallbackController

  def index(conn, _params) do
    component_categories = ComponentCategories.list_component_categories
    component_definitions = ComponentDefinitions.list_component_definitions
    render(conn, :index,
      component_categories: component_categories,
      component_definitions: component_definitions
    )
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{ "definitionId" => component_definition_id, "classes" => classes }) do
    Logger.info("###### Received component_definition_id #{inspect(component_definition_id)}")
    Logger.info("###### Received classes #{inspect(classes)}")
    render(conn, :show)
  end
end
