defmodule BeaconWeb.API.ComponentJSON do
  @moduledoc false

  alias Beacon.Content.Component

  def index(%{components: components}) do
    %{data: for(component <- components, do: data(component))}
  end

  def show(%{component: component}) do
    %{data: data(component)}
  end

  def show_ast(%{component: component, assigns: assigns}) do
    {:ok, ast} = Beacon.Template.HEEx.JSONEncoder.encode(component.site, component.example, assigns)
    data = Map.put(data(component), :ast, ast)
    %{data: data}
  end

  defp data(%Component{} = component) do
    %{
      id: component.id,
      name: component.name,
      category: component.category,
      thumbnail: component.thumbnail,
      template: component.template,
      example: component.example
    }
  end
end
