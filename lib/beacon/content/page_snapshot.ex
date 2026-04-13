defmodule Beacon.Content.PageSnapshot do
  @moduledoc """
  Represents the template of a `Beacon.Content.Page` at a specific moment in time.

  PageSnapshots don't exist on their own, but are created as part of a `Beacon.Content.PageEvent`
  whenever a Page is created, published, or unpublished.

  > #### Do not create or edit page snapshots manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.

  """

  use Beacon.Schema

  @type t :: %__MODULE__{}

  schema "beacon_page_snapshots" do
    field :site, Beacon.Types.Site
    field :schema_version, :integer
    field :page, Beacon.Types.Binary
    field :page_id, Ecto.UUID
    field :path, :string
    field :title, :string
    field :template, :string
    field :format, Beacon.Types.Atom, default: :heex
    field :extra, :map, default: %{}
    field :ast, :map
    field :meta_description, :string
    field :canonical_url, :string
    field :robots, :string
    field :og_title, :string
    field :og_description, :string
    field :og_image, :string
    field :twitter_card, :string
    field :date_modified, :utc_datetime_usec
    field :template_type_id, Ecto.UUID
    field :fields, :map, default: %{}
    belongs_to :event, Beacon.Content.PageEvent
    timestamps updated_at: false
  end
end
