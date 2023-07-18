defmodule BeaconWeb.API.ComponentJSON do
  alias Beacon.Content.ComponentCategory
  alias Beacon.Content.ComponentDefinition
  require Logger

  @tag_for_name %{
    "title" => "h1",
    "paragraph" => "p",
    "link" => "a",
    "button" => "button",
    "aside" => "aside",
  }

  def index(%{component_categories: categories, component_definitions: definitions}) do
    %{
      menuCategories: [%{
        name: "Base",
        items: for(category <- categories, do: category_data(category))
      }],
      componentDefinitions: for(definition <- definitions, do: definition_data(definition))
    }
  end
  def show(%{definition: definition, attributes: attributes}) do
    component = %{
      id: "made-up-id",
      definitionId: definition.id,
      attributes: attributes,
      slot: nil,
      content: [],
      renderedHtml: ""
    }
    Map.merge(component, %{renderedHtml: render_component(definition.blueprint, component), content: [] })
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
      name: category.name,
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

  defp render_component(blueprint, data) when is_binary(blueprint), do: blueprint
  defp render_component(%{"name" => name, "attributes" => attributes, "content" => content}, data) do
    tag = @tag_for_name[name]
    render_component(%{ "tag" => tag, "attributes" => attributes, "content" => content}, data)
  end
  defp render_component(%{"tag" => tag, "attributes" => attributes, "content" => content}, data) do
    """
    <#{tag}#{render_attrs(attributes)}>
      #{content |> Enum.map(fn entry -> render_component(entry, data) end) |> Enum.join}
    </#{tag}>
    """
  end

  defp render_attrs(attributes) when attributes == %{}, do: ""
  defp render_attrs(attributes) do
    str = attributes |> Enum.map(fn {key, val} -> render_attr(key, val) end) |> Enum.join(" ")
    " " <> str
  end

  defp render_attr(key, val) when is_list(val) do
    "#{key}=\"#{val |> Enum.join(" ")}\""
  end

  defp render_attr(key, val) do
    "#{key}=\"#{val}\""
  end
end
