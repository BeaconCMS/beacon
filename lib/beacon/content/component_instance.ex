defmodule Beacon.Content.ComponentInstance do
  use Ecto.Schema
  import Ecto.Changeset

  alias Beacon.Content.ComponentInstance
  alias Beacon.Content.Page

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_component_instances" do
    field :data, :map

    belongs_to :page, Page

    timestamps()
  end

  @doc false
  def changeset(component_instance \\ %ComponentInstance{}, %{} = attrs) do
    component_instance
    |> cast(attrs, [:data, :page_id])
    |> validate_required([:data, :page_id])
    |> foreign_key_constraint(:page_id)
  end
end
