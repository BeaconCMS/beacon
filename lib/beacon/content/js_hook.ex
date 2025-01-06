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

  @type t :: %__MODULE__{}

  schema "beacon_js_hooks" do
    field :name, :string
    field :site, Beacon.Types.Site

    field :mounted, :string
    field :beforeUpdate, :string
    field :updated, :string
    field :destroyed, :string
    field :disconnected, :string
    field :reconnected, :string

    timestamps()
  end

  @doc false
  def changeset(js_hook, attrs) do
    required = [:name, :site]

    optional = [
      :mounted,
      :beforeUpdate,
      :updated,
      :destroyed,
      :disconnected,
      :reconnected
    ]

    js_hook
    |> cast(attrs, required ++ optional)
    |> validate_required(required)
  end
end
