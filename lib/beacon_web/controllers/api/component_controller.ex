defmodule BeaconWeb.API.ComponentController do
  use BeaconWeb, :controller
  alias Beacon.ComponentCategories
  alias Beacon.ComponentDefinitions
  alias Ecto.UUID

  @tag_for_name %{
    "title" => "h1",
    "paragraph" => "p",
    "link" => "a",
    "button" => "button",
    "aside" => "aside",
  }
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
    component = build_component(definition.blueprint)
    render(conn, :show, component: component)
  end

  defp build_component(entry) when is_binary(entry), do: entry
  defp build_component(%{ "tag" => tag, "attributes" => attributes, "content" => content }) do
    attributes = attributes |> Map.put("id", UUID.generate())
    content = content |> Enum.map(&build_component(&1))
    %{ "tag" => tag, "attributes" => attributes, "content" => content }
  end
  defp build_component(%{ "name" => name, "attributes" => attributes, "content" => content }) do
    build_component(%{ "tag" => @tag_for_name[name], "attributes" => attributes, "content" => content })
  end
end
