defmodule Beacon.Content.InfoHandler do
  @moduledoc """
  Beacon's representation of a LiveView [handle_info/2](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#c:handle_info/2)
  that applies to all of a site's pages.

  This is the Elixir code which will handle messages from other Elixir processes.

  > #### Do not create or edit info handlers manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
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
          msg: binary(),
          code: binary(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "beacon_info_handlers" do
    field :site, Beacon.Types.Site
    field :msg, :string
    field :code, :string

    timestamps()
  end

  @doc false
  def changeset(%__MODULE__{} = info_handler, attrs) do
    fields = ~w(site msg code)a

    info_handler
    |> cast(attrs, fields)
    |> validate_required(fields)
  end
end
