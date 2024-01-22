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
    |> validate_required([:site])
  end

  def path_changeset(%__MODULE__{} = live_data, attrs) do
    cast(live_data, attrs, [:path], empty_values: [nil])
  end
end
