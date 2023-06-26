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

  use Ecto.Schema
  alias Beacon.Content.Layout

  @timestamps_opts type: :utc_datetime_usec

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          site: Beacon.Types.Site.t(),
          layout_id: Ecto.UUID.t(),
          layout: Layout.t(),
          event: String.t(),
          inserted_at: NaiveDateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_layout_events" do
    field :site, Beacon.Types.Site
    field :event, Ecto.Enum, values: [:created, :published]
    belongs_to :layout, Layout
    timestamps updated_at: false
  end
end
