defmodule Beacon.Pages.PageVersion do
  use Ecto.Schema
  import Ecto.Changeset

  alias Beacon.Pages.Page
  alias Beacon.Pages.PageVersion

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_page_versions" do
    field(:template, :string)
    field(:version, :integer)

    belongs_to(:page, Page)

    timestamps()
  end

  @doc false
  def changeset(page_version \\ %PageVersion{}, attrs) do
    page_version
    |> cast(attrs, [:version, :template, :page_id])
    |> validate_required([:version, :template, :page_id])
  end
end
