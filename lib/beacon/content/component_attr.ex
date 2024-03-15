defmodule Beacon.Content.ComponentAttr do
  @moduledoc """
  beacon_component_attrs
  """

  use Beacon.Schema

  alias Beacon.Content.Component

  @type t :: %__MODULE__{}

  schema "beacon_component_attrs" do
    field :name, :string
    field :type, :string
    field :opts, Beacon.Types.JsonArrayMap, default: []

    belongs_to :component, Component

    timestamps()
  end

  @doc false
  def changeset(component, attrs) do
    component
    |> cast(attrs, [:name, :type, :opts])
    |> validate_required([:name, :type])
  end
end
