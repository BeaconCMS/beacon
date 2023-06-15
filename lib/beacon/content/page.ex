defmodule Beacon.Content.Page do
  @moduledoc """
  Pages are the central piece of content in Beacon used to render templates with meta tags, components, and other resources.

  Pages are rendered as a LiveView handled by Beacon.

  Pages can be extended with custom fields, see `Beacon.Content.PageField`

  ## SEO

  Meta Tags

  Raw Schema

  > #### Do not create or edit pages manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Beacon.Layouts.Layout
  alias Beacon.Pages.Page
  alias Beacon.Pages.PageEvent
  alias Beacon.Pages.PageHelper
  alias Beacon.Pages.PageVersion
  alias Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_pages" do
    field :site, Beacon.Types.Site
    field :path, :string
    field :title, :string
    field :description, :string
    field :template, :string
    field :meta_tags, {:array, :map}, default: []
    field :raw_schema, {:array, :map}, default: []
    field :order, :integer, default: 1
    field :format, Beacon.Types.Atom, default: :heex
    field :extra, :map, default: %{}

    belongs_to :layout, Layout

    has_many :events, PageEvent
    has_many :helpers, PageHelper

    timestamps()
  end

  @doc false
  def changeset(page \\ %Page{}, %{} = attrs) do
  end
end
