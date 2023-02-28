defmodule Beacon.Layouts.Layout do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: String.t(),
          body: String.t(),
          meta_tags: [map()],
          site: Beacon.Type.Site.t(),
          stylesheet_urls: [String.t()],
          title: String.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_layouts" do
    field :site, Beacon.Type.Site
    field :title, :string
    field :body, :string
    field :meta_tags, {:array, :map}, default: []
    field :stylesheet_urls, {:array, :string}

    timestamps()
  end

  @doc false
  def changeset(layout, attrs) do
    layout
    |> cast(attrs, [:site, :title, :body, :meta_tags, :stylesheet_urls])
    # TODO: make stylesheet optional
    |> validate_required([:site, :title, :body, :stylesheet_urls])
  end
end
