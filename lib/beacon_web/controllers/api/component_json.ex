defmodule BeaconWeb.API.ComponentJSON do
  alias Beacon.ComponentCategories.ComponentCategory
  alias Beacon.ComponentDefinitions.ComponentDefinition
  require Logger
  def index(%{component_categories: categories, component_definitions: definitions}) do
    %{
      menuCategories: [%{
        name: "Base",
        items: for(category <- categories, do: category_data(category))
      }],
      componentDefinitions: for(definition <- definitions, do: definition_data(definition))
    }
  end

#   let autoincrementId = 1;
# export function _renderComponent(component: Component) {
#   component.id ||= String(autoincrementId++);
#   let renderedHtml = renderers[component.definitionId](component);
#   return {
#     ...component,
#     renderedHtml
#   }

  def show(%{definition: definition, classes: classes}) do
    component = %{
      id: "made-up-id",
      definitionId: definition.id,
      classes: classes,
      href: nil,
      slot: nil,
      content: [],
      renderedHtml: ""
    }
    Map.merge(component, render_component_definition(definition, component))
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

  defp render_component_definition(definition, data) do
    html = """
    <div>
      <h1>This is a test</h1>
      <p class="text-blue-500">This is a paragraph</p>
    </div>
    """
    %{
      renderedHtml: html,
      content: []
    }
  end
end



# comp.content ||= [
#   {
#     id: `title-${comp.id}`,
#     definitionId: ComponentDefinitionId.title,
#     classes: ['text-blue-500', 'text-xl'],
#     content: [`I am the component ${comp.definitionId}`],
#     renderedHtml: null
#   },
#   {
#     id: `paragraph-${comp.id}`,
#     definitionId: ComponentDefinitionId.paragraph,
#     classes: ['text-md'],
#     slot: true,
#     content: [
#       {
#         id: `link-1-${comp.id}`,
#         definitionId: ComponentDefinitionId.link,
#         classes: ['px-2', 'font-bold'],
#         href: '/product',
#         content: ['Product'],
#         renderedHtml: null
#       },
#       {
#         id: `link-2-${comp.id}`,
#         definitionId: ComponentDefinitionId.link,
#         classes: ['px-2', 'font-bold'],
#         href: '/pricing',
#         content: ['Pricing'],
#         renderedHtml: null
#       },
#       {
#         id: `link-3-${comp.id}`,
#         definitionId: ComponentDefinitionId.link,
#         classes: ['px-2', 'font-bold'],
#         href: '/about-us',
#         content: ['About us'],
#         renderedHtml: null
#       }
#     ],
#     renderedHtml: null
#   },
#   {
#     id: `aside-${comp.id}`,
#     definitionId: ComponentDefinitionId.aside,
#     classes: ['bg-gray-200'],
#     content: [
#       'This is some sample html',
#       {
#         id: `button-1-${comp.id}`,
#         definitionId: ComponentDefinitionId.button,
#         classes: ["bg-blue-500", "hover:bg-blue-700", "text-white", "font-bold", "py-2", "px-4", "rounded", "mx-2"],
#         content: ['Sign in'],
#         renderedHtml: null
#       },
#       ' and ',
#       {
#         id: `button-2-${comp.id}`,
#         definitionId: ComponentDefinitionId.button,
#         classes: ["bg-blue-500", "hover:bg-blue-700", "text-white", "font-bold", "py-2", "px-4", "rounded", "mx-2"],
#         content: ['Sign up'],
#         renderedHtml: null
#       },
#       ' for you to play with'
#     ],
#     renderedHtml: null
#   }
# ];

# let html = `<div data-id=${comp.id} data-root="true">${
#   comp.content ? comp.content.map((contentEntry) => {
#     return typeof contentEntry === 'string' ? contentEntry : renderers[contentEntry.definitionId](contentEntry)
#   }).join('') : ''
# }</div>`;
