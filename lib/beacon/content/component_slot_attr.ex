defmodule Beacon.Content.ComponentSlotAttr do
  @moduledoc false

  use Beacon.Schema

  alias Beacon.Content.ComponentSlot

  @type t :: %__MODULE__{}

  schema "beacon_component_slot_attrs" do
    field :name, :string
    field :type, :string
    field :struct_name, :string
    field :opts, Beacon.Types.Binary, default: []

    belongs_to :slot, ComponentSlot, foreign_key: :slot_id

    timestamps()
  end

  @doc false
  def changeset(component, attrs) do
    component
    |> cast(attrs, [:name, :type, :struct_name, :opts])
    |> validate_required([:name, :type])
    |> validate_struct_name_required()
  end

  def validate_struct_name_required(changeset) do
    type = get_field(changeset, :type)
    struct_name = get_field(changeset, :struct_name)

    if type == "struct" and is_nil(struct_name) do
      add_error(changeset, :struct_name, "is required when type is 'struct'")
    else
      changeset
    end
  end
end
