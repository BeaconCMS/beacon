defmodule Beacon.Content.PageSnapshot do
  @moduledoc """
  Page snapshots

  > #### Do not create or edit page snapshots manually {: .warning}
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
          schema_version: pos_integer(),
          page_id: Ecto.UUID.t(),
          page: Beacon.Content.Page.t(),
          event_id: Ecto.UUID.t(),
          event: Beacon.Content.PageEvent.t() | nil,
          inserted_at: DateTime.t()
        }

  schema "beacon_page_snapshots" do
    field :site, Beacon.Types.Site
    field :schema_version, :integer
    field :page_id, Ecto.UUID
    field :page, Beacon.Types.Binary
    belongs_to :event, Beacon.Content.PageEvent
    timestamps updated_at: false
  end
end
