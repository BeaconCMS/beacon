defmodule Beacon.Content.LiveDataAssign do
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

  alias Beacon.Content.LiveDataPath

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          live_data_path_id: Ecto.UUID.t(),
          live_data_path: LiveDataPath.t(),
          assign: String.t(),
          format: :text | :elixir,
          code: String.t()
        }

  @formats [:text, :elixir]

  schema "beacon_live_data_assigns" do
    field :assign, :string
    field :format, Ecto.Enum, values: @formats
    field :code, :string

    belongs_to :live_data_path, LiveDataPath

    timestamps()
  end

  def changeset(%__MODULE__{} = live_data_assign, attrs) do
    fields = ~w(assign format code live_data_path_id)a

    live_data_assign
    |> cast(attrs, fields)
    |> validate_required(fields)
  end

  def formats, do: @formats
end
