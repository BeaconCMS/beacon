defmodule Beacon.MediaLibrary.AssetFields.AltText do
  @moduledoc false

  use Phoenix.Component
  import BeaconWeb.CoreComponents
  import Ecto.Changeset

  @behaviour Beacon.MediaLibrary.AssetField

  @impl true
  def name, do: :alt

  @impl true
  def type, do: :string

  @impl true
  def render_input(assigns) do
    ~H"""
    <.input type="text" label="Alt Text" field={@field} />
    """
  end

  @impl true
  def render_show(assigns) do
    ~H"""
    <.input type="text" label="Alt Text" value={@value} />
    """
  end

  @impl true
  def changeset(data, attrs, _metadata) do
    data
    |> cast(attrs, [:alt])
  end
end
