defmodule BeaconWeb.API.ComponentController do
  use BeaconWeb, :controller

  alias Beacon.Content
  alias Beacon.BlueprintConverter
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
    component_definitions = Content.list_components(:dev)
    render(conn, :index, component_definitions: component_definitions)
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"definitionId" => component_definition_id, "pageId" => page_id}) do
    definition = Content.get_component_by(:dev, id: component_definition_id)
    page = Content.get_page!(page_id)
    [parsed_template] = BlueprintConverter.parse_html(definition.body)
    component_data = build_component(parsed_template)
    Logger.debug("page")
    Logger.debug(page)
    rendered_html = BlueprintConverter.generate_html(UUID.generate(), component_data)
    Logger.debug("rendered_html")
    Logger.debug(rendered_html)
    {:ok, page } = Content.update_page(page, %{ template: page.template <> rendered_html })
    render(conn, :show, page: page)
  end

  def create(conn, %{"definitionId" => component_definition_id}) do
    definition = Content.get_component_by(:dev, id: component_definition_id)
    [parsed_template] = BlueprintConverter.parse_html(definition.body)
    component_data = build_component(parsed_template)
    rendered_html = BlueprintConverter.generate_html(UUID.generate(), component_data)
    render(conn, :show, renderedHtml: rendered_html)
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
