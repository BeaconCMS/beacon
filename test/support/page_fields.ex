defmodule Beacon.BeaconTest.PageFields.TagsField do
  use Phoenix.Component
  import BeaconWeb.CoreComponents
  import Ecto.Changeset

  @behaviour Beacon.PageField

  @impl true
  def name, do: :tags

  @impl true
  def type, do: :string

  @impl true
  def render(assigns) do
    ~H"""
    <.input type="text" label="Tags" field={@field} />
    """
  end

  @impl true
  def changeset(data, attrs) do
    data
    |> cast(attrs, [:tags])
  end
end
