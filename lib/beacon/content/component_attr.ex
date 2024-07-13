defmodule Beacon.Content.ComponentAttr do
  @moduledoc false

  use Beacon.Schema

  alias Beacon.Content.Component

  @type t :: %__MODULE__{}

  schema "beacon_component_attrs" do
    field :name, :string
    field :type, :string
    field :struct_name, :string
    field :opts, Beacon.Types.Binary, default: []

    belongs_to :component, Component

    timestamps()
  end

  @doc false
  def changeset(component, attrs) do
    component
    |> cast(attrs, [:id, :name, :type, :struct_name, :opts, :component_id])
    |> validate_required([:name, :type])
    |> validate_format(:name, ~r/^[a-zA-Z0-9_!?]+$/, message: "can only contain letters, numbers, and underscores")
    |> Component.validate_if_struct_name_required()
    |> Component.validate_struct_name()
    |> Component.validate_non_empty_examples_opts()
    |> Component.validate_non_empty_values_opts()
    |> Component.validate_equivalent_options()
    |> Component.validate_default_opts_is_in_values_opts()
    |> Component.validate_type_and_values_opts()
    |> Component.validate_type_and_default_opts()
    |> Component.validate_struct_name_and_default_opts()
    |> Component.validate_type_and_examples_opts()
  end
end
