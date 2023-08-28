defmodule BeaconWeb.API.ComponentJSON do
  @moduledoc false

  alias Beacon.Content.Component

  def index(%{components: components}) do
    %{data: for(component <- components, do: data(component))}
  end

  def show(%{component: component, site: site}) do
    {:ok, ast} = Beacon.Template.HEEx.JSONEncoder.encode(site, component.body)

    %{
      data: %{ast: ast}
    }
  end

  def show(%{component: component}) do
    %{data: data(component)}
  end

  defp data(%Component{} = component) do
    %{
      id: component.id,
      name: component.name,
      body: component.body,
      category: component.category,
      thumbnail: component.thumbnail
    }
  end
end
