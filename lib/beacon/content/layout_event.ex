defmodule Beacon.Content.LayoutEvent do
  @moduledoc """
  Layout events

  > #### Do not create or edit layout events manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.

  """

  use Beacon.Schema
  alias Beacon.Content.Layout

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          site: Beacon.Types.Site.t(),
          layout_id: Ecto.UUID.t(),
          layout: Layout.t(),
          event: String.t(),
          inserted_at: DateTime.t()
        }

  schema "beacon_layout_events" do
    field :site, Beacon.Types.Site
    field :event, Ecto.Enum, values: [:created, :published]
    belongs_to :layout, Layout
    has_one :snapshot, Beacon.Content.LayoutSnapshot, foreign_key: :event_id
    timestamps updated_at: false
  end
end
