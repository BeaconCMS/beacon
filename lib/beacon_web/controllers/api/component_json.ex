defmodule BeaconWeb.API.ComponentJSON do
  alias Beacon.ComponentCategories.ComponentCategory
  alias Beacon.ComponentDefinitions.ComponentDefinition

  def index(%{component_categories: categories, component_definitions: definitions}) do
    %{
      menuCategories: [%{
        name: "Base",
        items: for(category <- categories, do: category_data(category))
      }],
      componentDefinitions: for(definition <- definitions, do: definition_data(definition))
    }
  end

  def show(%{}) do
    %{
      data: "still a WIP"
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
      categoryId: definition.component_category_id,
      name: definition.name,
      thumbnail: definition.thumbnail,
    }
  end
end
