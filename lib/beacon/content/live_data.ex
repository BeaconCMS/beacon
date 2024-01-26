defmodule Beacon.Content.LiveData do
  @moduledoc """
  The LiveData schema scopes `LiveDataAssign`s to `Page`s via site and path.

  > #### Do not create or edit live data manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.

  """

  use Beacon.Schema

  alias Beacon.Content.LiveDataAssign

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          site: Beacon.Types.Site.t(),
          path: String.t(),
          assigns: [LiveDataAssign]
        }

  schema "beacon_live_data" do
    field :site, Beacon.Types.Site
    field :path, :string

    has_many :assigns, LiveDataAssign

    timestamps()
  end

  # Note: `empty_values: [nil]` is necessary in changesets below, as well as skipping validation
  # for `:path`, because we don't use a leading slash, so root path is "", which Ecto considers
  # an empty value by default.
  #
  # Eventually we will switch to including the leading slash
  # (see https://github.com/BeaconCMS/beacon/issues/395)
  # and we can remove the `:empty_values` option as well as validating the `:path`

  def changeset(%__MODULE__{} = live_data, attrs) do
    live_data
    |> cast(attrs, [:site, :path], empty_values: [nil])
    |> validate_path()
    |> validate_required([:site])
  end

  def path_changeset(%__MODULE__{} = live_data, attrs) do
    live_data
    |> cast(attrs, [:path], empty_values: [nil])
    |> validate_path()
  end

  # TODO: remove this after https://github.com/BeaconCMS/beacon/issues/395 is resolved
  def validate_path(%{changes: %{path: ""}} = changeset), do: changeset

  # This is the only case where an empty path segment is allowed
  def validate_path(%{changes: %{path: "/"}} = changeset), do: changeset

  def validate_path(changeset) do
    regex = ~r"
      ^                             # Start of path string
      (\/?(:[a-z])?[A-Za-z0-9-_]+)  # First segment may skip leading slash - for backwards compatibility
                                    # The above line can be removed after issue 395 is resolved
      (                             # Start of path segment
      \/                            # The rest of the path segments must contain a leading slash
      (:[a-z])?                     # Colon optional for capturing params
                                    # When used, the first character must be a lowercase letter
      [A-Za-z0-9-_]+                # Other characters can be alphanumeric including hyphen and underscore
      )*                            # End of path segment, there may be any number of segments
      $                             # End of path string
    "x

    validate_format(changeset, :path, regex)
  end
end
