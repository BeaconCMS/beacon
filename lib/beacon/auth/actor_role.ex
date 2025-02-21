defmodule Beacon.Auth.ActorRole do
  use Beacon.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          actor_id: String.t(),
          role_id: Ecto.UUID.t(),
          role: Beacon.Auth.Role.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "beacon_actors_roles" do
    field :actor_id, :string

    belongs_to :role, Beacon.Auth.Role

    timestamps()
  end

  def changeset(actor_role, attrs \\ %{}) do
    actor_role
    |> cast(attrs, [:actor_id, :role_id])
    |> validate_required([:actor_id, :role_id])
  end
end
