defmodule BeaconWeb.API.ComponentCategoryJSON do
  alias Beacon.ComponentCategories.ComponentCategory
  alias Beacon.ComponentDefinitions.ComponentDefinition

  def index(%{component_categories: categories, component_definitions: definitions}) do
    %{
      menuCategories: [%{
        name: "Base",
        items: for(category <- categories, do: category_data(category))
      }],
      componentDefinitions: definitions
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
      name: category.name,
    }
  end

  # @doc """
  # Renders a single component definition.
  # """
  defp definition_data(%ComponentDefinition{} = definition) do
    %{
      id: definition.id,
      category_id: definition.component_category_id,
      name: definition.name,
      thumbnail: definition.thumbnail,
    }
  end
end