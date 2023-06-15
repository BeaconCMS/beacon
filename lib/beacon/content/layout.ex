defmodule Beacon.Content.Layout do
  @moduledoc """
  Layouts are the wrapper content for `Beacon.Content.Page`.

  > #### Do not create or layouts pages manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @version 1

  @type t :: %__MODULE__{
          id: String.t(),
          site: Beacon.Types.Site.t(),
          title: String.t(),
          body: String.t(),
          meta_tags: [map()],
          stylesheet_urls: [String.t()],
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_layouts" do
    field :site, Beacon.Types.Site
    field :title, :string
    field :body, :string
    field :meta_tags, {:array, :map}, default: []
    field :stylesheet_urls, {:array, :string}, default: []

    timestamps()
  end

  @doc """
  Current data structure version.

  Bump when schema changes.
  """
  def version, do: @version

  @doc false
  def changeset(layout, attrs) do
    layout
    |> cast(attrs, [:site, :title, :body, :meta_tags, :stylesheet_urls])
    # TODO: make stylesheet optional
    |> validate_required([:site, :title, :body, :stylesheet_urls])
  end
end
