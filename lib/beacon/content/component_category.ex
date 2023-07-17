defmodule Beacon.Content.ComponentCategory do
  use Ecto.Schema
  import Ecto.Changeset

  alias Beacon.Content.ComponentCategory

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_component_categories" do
    field :name, :string

    timestamps()
  end

  @doc false
  def changeset(component_category \\ %ComponentCategory{}, %{} = attrs) do
    component_category
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:id, name: :component_categories_pkey)
    |> unique_constraint([:name])
  end
end
