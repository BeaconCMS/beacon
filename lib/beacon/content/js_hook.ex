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

  @type t :: %__MODULE__{}

  schema "beacon_js_hooks" do
    field :name, :string
    field :site, Beacon.Types.Site
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

    validate_change(changeset, :code, fn :code, _code ->
      case RuntimeJS.get_export(hook, cleanup: true) do
        {:ok, export} when export in ["default", hook.name] -> []
        {:ok, export} -> [name: {"does not match export", export: export}]
        {:error, :no_export} -> [code: "no export found"]
        {:error, :multiple_exports} -> [code: "multiple exports are not allowed"]
        {:error, _} -> [code: "syntax error: please double-check your code and try again"]
      end
    end)
  end
end
