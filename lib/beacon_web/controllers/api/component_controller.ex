defmodule BeaconWeb.API.ComponentController do
  use BeaconWeb, :controller

  alias Beacon.Content

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
  def create(conn, %{"definition_id" => component_definition_id, "page_id" => page_id}) do
    definition = Content.get_component_by(:dev, id: component_definition_id)
    page = Content.get_page!(page_id)
    {:ok, page} = Content.update_page(page, %{template: page.template <> definition.body})
    render(conn, :show, page: page)
  end

  def create(conn, %{"definition_id" => component_definition_id}) do
    definition = Content.get_component_by(:dev, id: component_definition_id)
    render(conn, :show, rendered_html: definition.body)
  end

  defp build_component(entry) when is_binary(entry), do: entry
  defp build_component(%{"tag" => "raw", "attributes" => _, "content" => content}), do: content

  defp build_component(%{"tag" => tag, "attributes" => attributes, "content" => content}) do
    content = Enum.map(content, &build_component/1)
    %{"tag" => tag, "attributes" => attributes, "content" => content}
  end

  defp build_component(%{"name" => name, "attributes" => attributes, "content" => content}) do
    build_component(%{"tag" => @tag_for_name[name], "attributes" => attributes, "content" => content})
  end
end
