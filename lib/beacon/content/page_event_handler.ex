defmodule Beacon.Content.PageEventHandler do
  @moduledoc """
  Beacon's representation of a LiveView [handle_event/3](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#c:handle_event/3).

  This is the Elixir code which will receive form submission or on-click events.

  > #### Do not create or edit page event handlers manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.

  """
  use Beacon.Schema

  import Ecto.Changeset

  alias Beacon.Content.Page
  alias Ecto.UUID

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: binary(),
          code: binary(),
          page_id: UUID.t(),
          page: Page.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "beacon_page_event_handlers" do
    field :name, :string
    field :code, :string

    belongs_to :page, Page

    timestamps()
  end

  @doc false
  def changeset(%__MODULE__{} = event_handler, attrs) do
    fields = ~w(name code)a

    event_handler
    |> cast(attrs, fields)
    |> validate_required(fields)
  end
end
