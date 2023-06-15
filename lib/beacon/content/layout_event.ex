defmodule Beacon.Content.LayoutEvent do
  @moduledoc """
  Layout events
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
