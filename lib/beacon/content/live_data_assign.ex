defmodule Beacon.Content.LiveDataAssign do
  @moduledoc """
  Dynamic key/value assigns to be used by `Beacon.Content.Page` templates and updated with `Beacon.Content.EventHandler`s.

  LiveDataAssigns don't exist on their own, but exist as part of a `Beacon.Content.LiveData` struct.

  > #### Do not create or edit live data manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.

  """

  use Beacon.Schema

  alias Beacon.Content.LiveData

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          key: String.t(),
          value: String.t(),
          format: :text | :elixir,
          live_data_id: Ecto.UUID.t(),
          live_data: LiveData.t()
        }

  @formats [:text, :elixir]

  schema "beacon_live_data_assigns" do
    field :key, :string
    field :value, :string
    field :format, Ecto.Enum, values: @formats

    belongs_to :live_data, LiveData

    timestamps()
  end

  def changeset(%__MODULE__{} = live_data_assign, attrs) do
    fields = ~w(key value format live_data_id)a

    live_data_assign
    |> cast(attrs, fields)
    |> validate_required(fields)
    |> validate_exclusion(:key, ~w(beacon uploads streams socket myself flash))
    |> validate_format(:key, ~r/^\S+$/)
  end

  def formats, do: @formats
end
