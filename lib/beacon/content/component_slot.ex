defmodule Beacon.Content.ComponentSlot do
  @moduledoc """
  Beacon's representation of Phoenix's [Slots](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#module-slots).

  ComponentSlots don't exist on their own, but always belong to a `Beacon.Content.Component`.

  > #### Do not create or edit component slots manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.
  """

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
    |> validate_opts()
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

  @doc false
  def validate_opts(changeset) do
    opts = get_field(changeset, :opts) |> maybe_binary_to_term()
    not_allowed = Keyword.keys(opts) -- [:required, :validate_attrs, :doc]

    cond do
      Enum.count(not_allowed) > 0 ->
        name = get_field(changeset, :name)
        add_error(changeset, :opts, "invalid opts for slot #{inspect(name)}: #{inspect(not_allowed)}")

      true ->
        changeset
    end
  end

  defp maybe_binary_to_term(opts) when is_binary(opts), do: :erlang.binary_to_term(opts)
  defp maybe_binary_to_term(opts), do: opts
end
