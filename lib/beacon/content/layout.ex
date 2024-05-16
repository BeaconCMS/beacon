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

  use Beacon.Schema

  @version 3

  @type t :: %__MODULE__{
          id: String.t(),
          site: Beacon.Types.Site.t(),
          title: String.t(),
          template: String.t(),
          meta_tags: [map()],
          resource_links: [map()],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "beacon_layouts" do
    field :site, Beacon.Types.Site
    field :title, :string
    field :template, :string, default: "<%= @inner_content %>"
    field :meta_tags, {:array, :map}, default: []
    field :resource_links, {:array, :map}, default: []

    timestamps()
  end

  @doc """
  Current data structure version.

  Bump when schema changes.
  """
  def version, do: @version

  @doc false
  def changeset(%__MODULE__{} = layout, attrs) do
    layout
    |> cast(attrs, [:site, :title, :template, :meta_tags, :resource_links])
    |> validate_required([:site, :title])
  end

  @doc false
  def fetch(layout, key), do: Map.fetch(layout, key)
end
