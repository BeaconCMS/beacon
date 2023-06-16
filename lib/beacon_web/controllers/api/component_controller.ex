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

  # def show(conn, %{"id" => id}) do
  #   page = Pages.get_page!(id)
  #   render(conn, :show, page: page)
  # end

  def create(conn, attrs) do
    Logger.info("###### Received attrs #{inspect(attrs)}")
    # Logger.info("###### Received component_definition_id #{inspect(component_definition_id)}")
    render(conn, :show)
  end
end
