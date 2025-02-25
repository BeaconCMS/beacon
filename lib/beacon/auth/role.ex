defmodule Beacon.Auth.Role do
  @moduledoc """
  Scopes roles to actions for Authz.

  > #### Do not create or edit roles manually {: .warning}
  >
  > Use the public functions in `Beacon.Auth` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.

  """
  use Beacon.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          site: Beacon.Types.Site.t(),
          name: String.t(),
          capabilities: [String.t()],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "beacon_roles" do
    field :site, Beacon.Types.Site
    field :name, :string
    field :capabilities, {:array, :string}

    timestamps()
  end

  @doc false
  def changeset(%__MODULE__{} = role, attrs) do
    fields = ~w(site name capabilities)a

    role
    |> cast(attrs, fields)
    |> validate_required(fields)
    |> unique_constraint([:site, :name])
  end
end
