defmodule Beacon.Content.PageVariant do
  @moduledoc """
  """
  use Beacon.Schema

  import Ecto.Changeset

  alias Beacon.Content.Page
  alias Ecto.UUID

  @type t :: %__MODULE__{
          id: UUID.t(),
          name: binary(),
          weight: integer(),
          template: binary(),
          page_id: UUID.t(),
          page: Page.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "page_variants" do
    field :name, :string
    field :weight, :integer
    field :template, :string

    belongs_to :page, Page

    timestamps()
  end

  @doc false
  def create_changeset(%__MODULE__{} = page, attrs) do
    fields = ~w(name weight template page_id)a

    page
    |> cast(attrs, fields)
    |> validate_required(fields)
  end
end
