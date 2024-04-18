defmodule Beacon.Content.ComponentSlot do
  @moduledoc """
  beacon_component_slots
  """

  use Beacon.Schema

  alias Beacon.Content.Component
  alias Beacon.Content.SlotAttr

  @type t :: %__MODULE__{}

  schema "beacon_component_slots" do
    field :name, :string
    field :opts, Beacon.Types.Binary, default: []

    belongs_to :component, Component
    has_many :attrs, SlotAttr, foreign_key: :slot_id

    timestamps()
  end

  @doc false
  def changeset(component, attrs) do
    component
    |> cast(attrs, [:name, :opts])
    |> validate_required([:name])
    |> cast_assoc(:attrs, with: &SlotAttr.changeset/2)
  end
end
