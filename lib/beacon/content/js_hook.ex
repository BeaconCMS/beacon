defmodule Beacon.Content.JSHook do
  @moduledoc """
  Stores a JS Hook which can be referenced from your Beacon pages, layouts, and components.

  > #### Do not create or edit JS Hooks manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.

  """

  use Beacon.Schema
  alias Beacon.RuntimeJS

  @type t :: %__MODULE__{
          id: UUID.t(),
          site: Site.t(),
          name: binary(),
          code: binary(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "beacon_js_hooks" do
    field :site, Beacon.Types.Site
    field :name, :string
    field :code, :string
    timestamps()
  end

  @doc false
  def changeset(js_hook, attrs) do
    fields = [:name, :site, :code]

    js_hook
    |> cast(attrs, fields)
    |> validate_required(fields)
    |> validate_format(:name, ~r/[a-zA-Z_][a-zA-Z0-9_]*/)
    |> validate_code()
  end

  @doc false
  def validate_code(changeset) do
    hook = apply_changes(changeset)

    case RuntimeJS.get_export(hook, cleanup: true) do
      {:ok, export} when export in ["default", hook.name] ->
        changeset

      {:ok, export} ->
        add_error(changeset, :name, "does not match export", export: export)

      {:error, :no_export} ->
        add_error(changeset, :code, "no export found")

      {:error, :multiple_exports} ->
        add_error(changeset, :code, "multiple exports are not allowed")

      {:error, _} ->
        add_error(changeset, :code, "syntax error: please double-check your code and try again")
    end
  end
end
