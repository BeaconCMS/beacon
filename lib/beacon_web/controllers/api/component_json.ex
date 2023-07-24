defmodule BeaconWeb.API.ComponentJSON do
  alias Beacon.Content.ComponentCategory
  alias Beacon.Content.ComponentDefinition

  def index(%{component_categories: categories, component_definitions: definitions}) do
    %{
      menuCategories: [
        %{
          name: "Base",
          items: for(category <- categories, do: category_data(category))
        }
      ],
      componentDefinitions: for(definition <- definitions, do: definition_data(definition))
    }
  end

  def show(%{component: component}) do
    %{"tag" => tag, "content" => content, "attributes" => attributes} = component.data
    attributes = attributes
    |> Map.put("id", component.id)
    |> Map.put("root", true)

    %{
      tag: tag,
      content: content,
      attributes: attributes,
      renderedHtml: render_node(%{"tag" => tag, "content" => content, "attributes" => attributes})
    }
  end

  # @doc """
  # Renders a list of pages.
  # """
  # def index(%{pages: pages}) do
  #   %{data: for(page <- pages, do: data(page))}
  # end

  # @doc """
  # Renders a single component category.
  # """
  defp category_data(%ComponentCategory{} = category) do
    %{
      id: category.id,
      name: category.name
    }
  end

  # @doc """
  # Renders a single component definition.
  # """
  defp definition_data(%ComponentDefinition{} = definition) do
    %{
      id: definition.id,
      categoryId: definition.component_category_id,
      name: definition.name,
      thumbnail: definition.thumbnail,
      blueprint: definition.blueprint
    }
  end

  defp render_node(node) when is_binary(node), do: node
  # Special case to just output content as HTML
  defp render_node(%{"tag" => "raw", "content" => content}), do: content

  defp render_node(%{"tag" => tag, "attributes" => attributes, "content" => content}) do
    """
    <#{tag}#{render_attrs(attributes)}>
      #{content |> Enum.map_join(&render_node(&1))}
    </#{tag}>
    """
  end

  defp render_attrs(attributes) when attributes == %{}, do: ""

  defp render_attrs(attributes) do
    str = Enum.map_join(attributes, " ", fn {key, val} -> render_attr(key, val) end)
    " " <> str
  end

  defp render_attr(key, val) when is_list(val), do: "#{key}=\"#{Enum.join(val, " ")}\""
  defp render_attr("id", val), do: "data-id=\"#{val}\""
  defp render_attr("slot", false), do: ""
  defp render_attr("slot", _), do: "data-slot"
  defp render_attr("root", _), do: "data-root"
  defp render_attr(key, val), do: "#{key}=\"#{val}\""
end
