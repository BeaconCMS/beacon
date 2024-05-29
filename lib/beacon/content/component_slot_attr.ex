defmodule Beacon.Content.ComponentSlotAttr do
  @moduledoc false

  use Beacon.Schema

  alias Beacon.Content.ComponentSlot

  @type t :: %__MODULE__{}

  schema "beacon_component_slot_attrs" do
    field :name, :string
    field :type, :string
    field :opts, Beacon.Types.Binary, default: []

    belongs_to :slot, ComponentSlot, foreign_key: :slot_id

    timestamps()
  end

  @doc false
  def changeset(component, attrs) do
    component
    |> cast(attrs, [:name, :type, :opts])
    |> validate_required([:name, :type])
  end
end
