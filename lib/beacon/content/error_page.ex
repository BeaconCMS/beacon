defmodule Beacon.Content.ErrorPage do
  @moduledoc """
  Stores a template which can be rendered for error responses.

  An ErrorPage contains four main fields:

    * `:status` - the status code for which this ErrorPage is to be used
    * `:template` - the template to be rendered
    * `:site` - the Beacon site which should use this page
    * `:layout_id` - the ID of the Beacon Layout which is used for rendering

  > #### Do not create or edit ErrorPages manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.

  """
  use Beacon.Schema

  import Beacon.Utils, only: [list_to_typespec: 1]
  import Ecto.Changeset

  # We can use Range.to_list/1 here when we upgrade to Elixir 1.15
  @valid_error_codes Enum.to_list(400..418) ++
                       Enum.to_list(421..426) ++
                       [428, 429, 431, 451] ++
                       Enum.to_list(500..508) ++
                       [510, 511]

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          site: Beacon.Types.Site.t(),
          status: error_code(),
          template: binary(),
          layout_id: Ecto.UUID.t(),
          layout: Beacon.Content.Layout.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @type error_code :: unquote(list_to_typespec(@valid_error_codes))

  schema "beacon_error_pages" do
    field :site, Beacon.Types.Site
    field :status, :integer
    field :template, :string

    belongs_to :layout, Beacon.Content.Layout

    timestamps()
  end

  @doc false
  def changeset(%__MODULE__{} = error_page, attrs) do
    fields = ~w(status template site layout_id)a

    error_page
    |> cast(attrs, fields)
    |> validate_required(fields)
    |> unique_constraint([:status, :site])
    |> validate_inclusion(:status, @valid_error_codes)
  end

  def valid_error_codes, do: @valid_error_codes
end
