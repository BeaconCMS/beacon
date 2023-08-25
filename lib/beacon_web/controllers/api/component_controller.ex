defmodule BeaconWeb.API.ComponentController do
  use BeaconWeb, :controller

  alias Beacon.Content

  action_fallback BeaconWeb.API.FallbackController

  def index(conn, %{"site" => site}) do
    component_definitions = Content.list_components(site, per_page: :infinity)
    render(conn, :index, component_definitions: component_definitions)
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"definition_id" => component_definition_id, "page_id" => page_id}) do
    page = Content.get_page!(page_id)
    definition = Content.get_component_by(page.site, id: component_definition_id)
    {:ok, page} = Content.update_page(page, %{template: page.template <> definition.body})
    render(conn, :show, page: page)
  end

  def create(conn, %{"definition_id" => component_definition_id, "page_id" => page_id}) do
    page = Content.get_page!(page_id)
    definition = Content.get_component_by(page.site, id: component_definition_id)
    render(conn, :show, rendered_html: definition.body, page: page)
  end
end
