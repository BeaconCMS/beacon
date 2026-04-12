defmodule Beacon.Content.PageQuery do
  @moduledoc """
  Binds a GraphQL query to a page.

  When a page is rendered, its associated queries are executed against
  the named GraphQL endpoints, and the results are available as assigns
  in the page template under the `result_alias` key.

  ## Variable Bindings

  The `variable_bindings` field maps GraphQL variable names to value sources:

      %{
        "slug" => %{"source" => "path_param", "key" => "slug"},
        "limit" => %{"source" => "literal", "value" => 10},
        "page" => %{"source" => "query_param", "key" => "page", "default" => "1"},
        "authorId" => %{"source" => "query_result", "from" => "get_author", "path" => "data.author.id"}
      }

  ## Dependencies

  Queries can depend on the results of other queries via the `depends_on` field.
  Independent queries execute in parallel; dependent queries execute sequentially
  after their dependency completes.
  """
  use Beacon.Schema

  import Ecto.Changeset

  alias Beacon.Content.Page

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          page_id: Ecto.UUID.t(),
          endpoint_name: binary(),
          query_string: binary(),
          variable_bindings: map(),
          result_alias: binary(),
          depends_on: binary() | nil,
          sort_order: integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "beacon_page_queries" do
    field :endpoint_name, :string
    field :query_string, :string
    field :variable_bindings, :map, default: %{}
    field :result_alias, :string
    field :depends_on, :string
    field :sort_order, :integer, default: 0

    belongs_to :page, Page

    timestamps()
  end

  @required_fields ~w(page_id endpoint_name query_string result_alias)a
  @optional_fields ~w(variable_bindings depends_on sort_order)a

  @doc false
  def changeset(%__MODULE__{} = page_query, attrs) do
    page_query
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_format(:result_alias, ~r/^[a-z][a-z0-9_]*$/, message: "must be a valid assign name (lowercase, alphanumeric, underscores)")
    |> validate_format(:endpoint_name, ~r/^[a-z][a-z0-9_]*$/, message: "must be lowercase alphanumeric with underscores")
    |> foreign_key_constraint(:page_id)
  end
end
