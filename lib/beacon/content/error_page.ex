defmodule Beacon.Content.ErrorPage do
  @moduledoc """
  Stores a template which can be rendered for error responses.

  An ErrorPage contains two main fields:

    * `:status` - the status code for which this ErrorPage is to be used
    * `:template` - the template to be rendered

  > #### Do not create or edit ErrorPages manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.

  """
  use Beacon.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          site: Beacon.Types.Site.t(),
          status: integer,
          template: binary(),
          layout_id: Ecto.UUID.t(),
          layout: Beacon.Content.Layout.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

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
  end
end
