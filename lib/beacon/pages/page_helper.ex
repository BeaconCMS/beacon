defmodule Beacon.Pages.PageHelper do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_page_helpers" do
    field :code, :string
    field :helper_name, :string
    field :helper_args, :string
    field :order, :integer, default: 1

    belongs_to :page, Beacon.Pages.Page

    timestamps()
  end

  @doc false
  def changeset(page_helper \\ %__MODULE__{}, attrs) do
    page_helper
    |> cast(attrs, [:code, :order, :helper_name, :helper_args, :page_id])
    |> validate_required([:code, :order, :helper_name, :helper_args, :page_id])
  end
end
