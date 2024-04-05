defmodule Beacon.Content.ComponentSlot do
  @moduledoc """
  beacon_component_slots
  """

  use Beacon.Schema

  alias Beacon.Content.Component

  @type t :: %__MODULE__{}

  schema "beacon_component_slots" do
    field :name, :string
    field :opts, Beacon.Types.Binary, default: []

    belongs_to :component, Component

    timestamps()
  end

  @doc false
  def changeset(component, attrs) do
    component
    |> cast(attrs, [:name, :opts])
    |> validate_required([:name])
  end
end
