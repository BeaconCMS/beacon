defmodule BeaconWeb.API.ComponentController do
  use BeaconWeb, :controller

  alias Beacon.BlueprintConverter
  alias Beacon.ComponentCategories
  alias Beacon.ComponentDefinitions
  alias Beacon.ComponentInstances
  alias Ecto.UUID

  require Logger

  @tag_for_name %{
    "title" => "h1",
    "paragraph" => "p",
    "link" => "a",
    "button" => "button",
    "aside" => "aside"
  }
  action_fallback BeaconWeb.API.FallbackController

  def index(conn, _params) do
    component_categories = ComponentCategories.list_component_categories()
    component_definitions = ComponentDefinitions.list_component_definitions()

    render(conn, :index,
      component_categories: component_categories,
      component_definitions: component_definitions
    )
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"definitionId" => component_definition_id, "pageId" => page_id, "attributes" => attributes}) do
    definition = ComponentDefinitions.get_component_definition!(component_definition_id)
    [parsed_template] = BlueprintConverter.parse_html(definition.blueprint)
    component_data = build_component(parsed_template)
    component_instance = ComponentInstances.create_component_instance!(%{data: component_data, page_id: page_id})
    render(conn, :show, component: component_instance)
  end

  def create(conn, %{"definitionId" => component_definition_id, "attributes" => attributes}) do
    definition = ComponentDefinitions.get_component_definition!(component_definition_id)
    [parsed_template] = BlueprintConverter.parse_html(definition.blueprint)
    component_data = build_component(parsed_template)
    render(conn, :show, component: %{id: UUID.generate(), data: component_data})
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = map) do
    data = Map.delete(map, "id")

    instance = ComponentInstances.get_component_instance!(id)

    case ComponentInstances.update_component_instance_data(instance, data) do
      {:ok, component_instance} ->
        render(conn, :show, component: component_instance)

      {:error, changeset} ->
        json(conn, changeset.errors)
    end
  end

  defp build_component(entry) when is_binary(entry), do: entry
  defp build_component(%{"tag" => "raw", "attributes" => _, "content" => content}), do: content

  defp build_component(%{"tag" => tag, "attributes" => attributes, "content" => content}) do
    attributes =  attributes
    |> Map.put("id", UUID.generate())
    content = Enum.map(content, &build_component/1)
    %{"tag" => tag, "attributes" => attributes, "content" => content}
  end

  defp build_component(%{"name" => name, "attributes" => attributes, "content" => content}) do
    build_component(%{"tag" => @tag_for_name[name], "attributes" => attributes, "content" => content})
  end
end
