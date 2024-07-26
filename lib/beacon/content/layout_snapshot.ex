defmodule Beacon.Content.LayoutSnapshot do
  @moduledoc """
  Represents the template of a `Beacon.Content.Layout` at a specific moment in time.

  LayoutSnapshots don't exist on their own, but are created as part of a `Beacon.Content.LayoutEvent`
  whenever a Layout is created or published.

  > #### Do not create or edit layout snapshots manually {: .warning}
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
          layout_id: Ecto.UUID.t(),
          layout: Beacon.Content.Layout.t(),
          event_id: Ecto.UUID.t(),
          event: Beacon.Content.LayoutEvent.t() | nil,
          inserted_at: DateTime.t()
        }

  schema "beacon_layout_snapshots" do
    field :site, Beacon.Types.Site
    field :schema_version, :integer
    field :layout_id, Ecto.UUID
    field :layout, Beacon.Types.Binary
    belongs_to :event, Beacon.Content.LayoutEvent
    timestamps updated_at: false
  end
end
