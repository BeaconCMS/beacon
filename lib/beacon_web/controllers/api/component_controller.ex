defmodule BeaconWeb.API.ComponentController do
  use BeaconWeb, :controller
  alias Beacon.ComponentCategories
  alias Beacon.ComponentDefinitions
  # require Logger

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
  def create(conn, %{ "definitionId" => component_definition_id, "attributes" => attributes}) do
    definition = ComponentDefinitions.get_component_definition!(component_definition_id)
    render(conn, :show, definition: definition, attributes: attributes)
  end
end
