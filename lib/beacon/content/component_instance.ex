defmodule Beacon.Content.ComponentInstance do
  use Ecto.Schema
  import Ecto.Changeset

  alias Beacon.Content.ComponentInstance

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_component_instances" do
    field :data, :map

    timestamps()
  end

  @doc false
  def changeset(component_instance \\ %ComponentInstance{}, %{} = attrs) do
    component_instance
    |> cast(attrs, [:data])
    |> validate_required([:data])
  end
end
