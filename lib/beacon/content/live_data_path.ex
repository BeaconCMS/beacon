defmodule Beacon.Content.LiveDataPath do
  @moduledoc """
  Dynamic assigns to be used by page templates and updated with page event handlers.

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
          live_data_assigns: [LiveDataAssign]
        }

  @formats [:text, :elixir]

  schema "beacon_live_data" do
    field :site, Beacon.Types.Site
    field :path, :string

    has_many :live_data_assigns, LiveDataAssign

    timestamps()
  end

  def changeset(%__MODULE__{} = live_data_path, attrs) do
    fields = ~w(site path)a

    live_data
    |> cast(attrs, fields)
    |> validate_required(fields)
  end

  def path_changeset(%__MODULE__{} = live_data_path, attrs) do
    live_data
    |> cast(attrs, [:path])
    |> validate_required([:path])
  end
end
