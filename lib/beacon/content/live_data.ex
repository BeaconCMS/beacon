defmodule Beacon.Content.LiveData do
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

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          site: Beacon.Types.Site.t(),
          path: String.t(),
          assign: String.t(),
          format: :text | :elixir,
          code: String.t()
        }

  @formats [:text, :elixir]

  schema "beacon_live_data" do
    field :site, Beacon.Types.Site
    field :path, :string
    field :assign, :string
    field :format, Ecto.Enum, values: @formats
    field :code, :string

    timestamps()
  end

  def changeset(%__MODULE__{} = live_data, attrs) do
    fields = ~w(site path assign format code)a

    live_data
    |> cast(attrs, fields)
    |> validate_required(fields)
  end

  def formats, do: @formats
end
