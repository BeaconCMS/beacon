defmodule Beacon.Content.Component do
  @moduledoc """
  Components

  > #### Do not create or edit components manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_components" do
    field :body, :string
    field :name, :string
    field :site, Beacon.Types.Site

    timestamps()
  end

  @doc false
  def changeset(component, attrs) do
    component
    |> cast(attrs, [:site, :name, :body])
    |> validate_required([:site, :name, :body])
  end
end
