defmodule Beacon.Content.PageSnapshot do
  @moduledoc """
  Page snapshots
  """

  use Ecto.Schema

  @timestamps_opts type: :utc_datetime_usec

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          site: Beacon.Types.Site.t(),
          schema_version: pos_integer(),
          page_id: Ecto.UUID.t(),
          page: Beacon.Content.Page.t(),
          event_id: Ecto.UUID.t(),
          event: Beacon.Content.PageEvent.t() | nil,
          inserted_at: NaiveDateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_page_snapshots" do
    field :site, Beacon.Types.Site
    field :schema_version, :integer
    field :page_id, Ecto.UUID
    field :page, Beacon.Types.Binary
    belongs_to :event, Beacon.Content.PageEvent
    timestamps updated_at: false
  end
end
