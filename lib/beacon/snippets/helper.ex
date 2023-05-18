defmodule Beacon.Snippets.Helper do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_snippet_helpers" do
    field :site, Beacon.Types.Atom
    field :name, :string
    field :body, :string

    timestamps()
  end
end
