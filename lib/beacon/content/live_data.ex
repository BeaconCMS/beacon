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

  def changeset(%__MODULE__{} = live_data, attrs) do
    live_data
    |> cast(attrs, [:site, :path])
    |> validate_required([:site])
    |> Beacon.Schema.validate_path()
  end

  def path_changeset(%__MODULE__{} = live_data, attrs) do
    live_data
    |> cast(attrs, [:path])
    |> Beacon.Schema.validate_path()
  end
end
