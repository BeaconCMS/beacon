defmodule Beacon.Pages.PageVersion do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_page_versions" do
    field :template, :string
    field :version, :integer

    belongs_to :page, Beacon.Pages.Page

    timestamps()
  end

  @doc false
  def changeset(page_version \\ %__MODULE__{}, attrs) do
    page_version
    |> cast(attrs, [:version, :template, :page_id])
    |> validate_required([:version, :template, :page_id])
  end
end
