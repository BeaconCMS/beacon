defmodule BeaconWeb.API.ComponentJSON do
  alias Beacon.Content.Component

  def index(%{component_definitions: definitions}) do
    %{
      menu_categories: [
        %{
          name: "Base",
          items: for(category <- Component.categories(), do: %{id: category, name: category})
        }
      ],
      componentDefinitions: for(definition <- definitions, do: definition_data(definition))
    }
  end

  def show(%{page: page}) do
    %{
      renderedHtml: page.template
    }
  end

  def show(%{renderedHtml: rendered_html}) do
    %{
      renderedHtml: rendered_html
    }
  end

  # @doc """
  # Renders a single component definition.
  # """
  defp definition_data(%Component{} = definition) do
    %{
      id: definition.id,
      category: definition.category,
      name: definition.name,
      thumbnail: definition.thumbnail,
      blueprint: definition.body
    }
  end
end
