defmodule Beacon.Content.PageEvent do
  @moduledoc """
  Page events
  """

  use Ecto.Schema
  alias Beacon.Content.Page

  @timestamps_opts type: :utc_datetime_usec

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
          inserted_at: NaiveDateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_page_events" do
    field :site, Beacon.Types.Site
    field :event, Ecto.Enum, values: [:created, :published, :unpublished]
    belongs_to :page, Page
    timestamps updated_at: false
  end
end
