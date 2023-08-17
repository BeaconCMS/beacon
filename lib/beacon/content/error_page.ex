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
          status: integer,
          template: binary(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "beacon_error_pages" do
    field :status, :integer
    field :template, :string

    timestamps()
  end

  # If we move to Elixir 1.15+ we can use Range.to_list/1 here
  @error_codes Enum.to_list(400..418) ++
                 Enum.to_list(421..426) ++
                 [428, 429, 431, 451] ++
                 Enum.to_list(500..508) ++
                 [510, 511]

  @doc false
  def changeset(%__MODULE__{} = error_page, attrs) do
    fields = [:status, :template]

    error_page
    |> cast(attrs, fields)
    |> validate_required(fields)
    |> validate_inclusion(:status, @error_codes)
  end
end
