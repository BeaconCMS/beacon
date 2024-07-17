defmodule Beacon.Content.ComponentSlot do
  use Beacon.Schema

  alias Beacon.Content.Component
  alias Beacon.Content.ComponentSlotAttr

  @type t :: %__MODULE__{}

  schema "beacon_component_slots" do
    field :name, :string
    field :opts, Beacon.Types.Binary, default: []

    belongs_to :component, Component
    has_many :attrs, ComponentSlotAttr, foreign_key: :slot_id

    timestamps()
  end

  @doc false
  def changeset(component, attrs, component_slots_names \\ []) do
    component
    |> cast(attrs, [:name, :opts])
    |> validate_required([:name])
    |> validate_unique_component_slot_names(component_slots_names)
    |> cast_assoc(:attrs, with: &ComponentSlotAttr.changeset/2)
  end

  @doc false
  def validate_unique_component_slot_names(changeset, component_slots_names) do
    name = get_field(changeset, :name)

    if name in component_slots_names do
      add_error(changeset, :name, "a duplicate slot with name '#{name}' already exists")
    else
      changeset
    end
  end
end
