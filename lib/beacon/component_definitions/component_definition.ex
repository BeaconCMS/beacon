defmodule Beacon.ComponentDefinitions.ComponentDefinition do
  use Ecto.Schema
  import Ecto.Changeset

  alias Beacon.ComponentDefinitions.ComponentDefinition

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_component_definitions" do
    field :name, :string
    field :thumbnail, :string
    belongs_to :component_category, Beacon.ComponentCategories.ComponentCategory

    timestamps()
  end

  @doc false
  def changeset(component_category \\ %ComponentDefinition{}, %{} = attrs) do
    component_category
    |> cast(attrs, [:name, :thumbnail, :component_category_id])
    |> validate_required([:name, :thumbnail])
    |> unique_constraint(:id, name: :component_definitions_pkey)
    |> unique_constraint([:name, :thumbnail])
  end
end
