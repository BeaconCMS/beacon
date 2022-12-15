defmodule Beacon.Pages.PageHelper do
  use Ecto.Schema
  import Ecto.Changeset

  alias Beacon.Pages.PageHelper

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_page_helpers" do
    field :code, :string
    field :helper_name, :string
    field :helper_args, :string
    field :order, :integer, default: 1
    field :page_id, :binary_id

    timestamps()
  end

  @doc false
  def changeset(page_helper \\ %PageHelper{}, attrs) do
    page_helper
    |> cast(attrs, [:code, :order, :helper_name, :helper_args, :page_id])
    |> validate_required([:code, :order, :helper_name, :helper_args, :page_id])
  end
end
