defmodule Beacon.Content.GraphQLEndpoint do
  @moduledoc """
  Represents a named GraphQL endpoint that Beacon can query for page data.

  Each endpoint has a URL, authentication configuration, and an introspected
  or manually uploaded schema that describes available queries and mutations.

  > #### Do not create or edit GraphQL endpoints manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.
  """
  use Beacon.Schema

  import Ecto.Changeset

  alias Beacon.Types.Site

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          site: Site.t(),
          name: binary(),
          url: binary(),
          auth_type: binary(),
          auth_header: binary(),
          auth_value_encrypted: binary() | nil,
          introspected_schema: map() | nil,
          sdl_schema: binary() | nil,
          default_ttl: integer(),
          timeout_ms: integer(),
          max_retries: integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "beacon_graphql_endpoints" do
    field :site, Site
    field :name, :string
    field :url, :string
    field :auth_type, :string, default: "bearer"
    field :auth_header, :string, default: "Authorization"
    field :auth_value_encrypted, Beacon.Encrypted.Binary
    field :introspected_schema, :map
    field :sdl_schema, :string
    field :default_ttl, :integer, default: 60
    field :timeout_ms, :integer, default: 10_000
    field :max_retries, :integer, default: 2

    timestamps()
  end

  @required_fields ~w(site name url)a
  @optional_fields ~w(auth_type auth_header auth_value_encrypted introspected_schema sdl_schema default_ttl timeout_ms max_retries)a

  @doc false
  def changeset(%__MODULE__{} = endpoint, attrs) do
    endpoint
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:auth_type, ~w(bearer header none))
    |> validate_format(:url, ~r/^https?:\/\//, message: "must start with http:// or https://")
    |> validate_format(:name, ~r/^[a-z][a-z0-9_]*$/, message: "must be lowercase alphanumeric with underscores")
    |> validate_number(:default_ttl, greater_than_or_equal_to: 0)
    |> validate_number(:timeout_ms, greater_than: 0)
    |> validate_number(:max_retries, greater_than_or_equal_to: 0)
    |> unique_constraint([:site, :name])
  end
end
