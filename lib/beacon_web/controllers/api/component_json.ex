defmodule BeaconWeb.API.ComponentJSON do
  @moduledoc false

  alias Beacon.Content.Component

  def index(%{component_definitions: definitions}) do
    %{
      menu_categories: [
        %{
          name: "Base",
          items: for(category <- Component.categories(), do: %{id: category, name: category})
        }
      ],
      component_definitions: for(definition <- definitions, do: definition_data(definition))
    }
  end

  def show(%{page: page}) do
    BeaconWeb.API.PageJSON.show(%{page: page})
  end

  def show(%{rendered_html: rendered_html, page: page}) do
    %{
      data: %{ast: Beacon.Template.HEEx.JSONEncoder.encode(rendered_html, page.site)}
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
