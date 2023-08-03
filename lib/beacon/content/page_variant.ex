defmodule Beacon.Content.PageVariant do
  @moduledoc """
  Stores an alternate template which can be randomly rendered as a replacement for a Page's standard template.

  A PageVariant contains three main fields:

    * `:name` - a brief description of what change(s) the variant template provides
    * `:weight` - the percentage of page renders which should use this template (0 - 100)
    * `:template` - the template which should be rendered whenever this variant is used

  > #### Do not create or edit pages manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.
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
  def changeset(%__MODULE__{} = page, attrs) do
    fields = ~w(name weight template)a

    page
    |> cast(attrs, fields)
    |> validate_required(fields)
    |> validate_number(:weight, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end
