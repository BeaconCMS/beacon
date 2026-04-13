defmodule Beacon.Content.Layout do
  @moduledoc """
  The wrapper content for a `Beacon.Content.Page`.

  > #### Do not create or layouts pages manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.
  """

  use Beacon.Schema

  @version 4

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
    field :template, :string, default: "{{ inner_content }}"
    field :meta_tags, {:array, :map}, default: []
    field :resource_links, {:array, :map}, default: []
    field :default_og_image, :string
    field :default_twitter_card, :string
    field :ast, :map

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
    |> cast(attrs, [:site, :title, :template, :meta_tags, :resource_links, :default_og_image, :default_twitter_card])
    |> validate_required([:site, :title])
  end

  @doc false
  def fetch(layout, key), do: Map.fetch(layout, key)
end
