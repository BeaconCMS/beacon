defmodule Beacon.Content.LayoutSnapshot do
  @moduledoc """
  Layout snapshot
  """

  use Ecto.Schema

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          site: Beacon.Types.Site.t(),
          layout: Beacon.Content.Layout.t(),
          event_id: Ecto.UUID.t(),
          event: Beacon.Content.LayoutEvent.t(),
          inserted_at: NaiveDateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_layout_snapshots" do
    field :site, Beacon.Types.Site
    field :layout, Beacon.Types.Binary
    belongs_to :event, Beacon.Content.LayoutEvent
    timestamps updated_at: false
  end
end
