defmodule Beacon.Layouts.Layout do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "layouts" do
    field(:body, :string)
    field(:meta_tags, :map)
    field(:site, :string)
    field(:stylesheet_urls, {:array, :string})
    field(:title, :string)

    timestamps()
  end

  @doc false
  def changeset(layout, attrs) do
    layout
    |> cast(attrs, [:site, :title, :body, :meta_tags, :stylesheet_urls])
    |> validate_required([:site, :title, :body, :meta_tags, :stylesheet_urls])
  end
end
