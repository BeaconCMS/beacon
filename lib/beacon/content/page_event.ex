defmodule Beacon.Content.PageEvent do
  @moduledoc """
  Represents a point in time when a `Beacon.Content.Page` was created, published, or unpublished.

  At that time, a `Beacon.Content.PageSnapshot` is created and stored with the PageEvent.

  > #### Do not create or edit page events manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.

  """

  use Beacon.Schema
  alias Beacon.Content.Page

  @typedoc """
  The event name. Can be one of :created, :published, :unpublished
  """
  @type event :: :created | :published | :unpublished

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          site: Beacon.Types.Site.t(),
          page_id: Ecto.UUID.t(),
          page: Page.t(),
          event: event(),
          inserted_at: DateTime.t()
        }

  schema "beacon_page_events" do
    field :site, Beacon.Types.Site
    field :event, Ecto.Enum, values: [:created, :published, :unpublished]
    belongs_to :page, Page
    has_one :snapshot, Beacon.Content.PageSnapshot, foreign_key: :event_id
    timestamps updated_at: false
  end
end
