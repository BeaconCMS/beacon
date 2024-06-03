defmodule Beacon.Content.Component do
  @moduledoc """
  Components

  > #### Do not create or edit components manually {: .warning}
  >
  > Use the public functions in `Beacon.Content` instead.
  > The functions in that module guarantee that all dependencies
  > are created correctly and all processes are updated.
  > Manipulating data manually will most likely result
  > in inconsistent behavior and crashes.
  """

  use Beacon.Schema

  alias Beacon.Content.ComponentAttr
  alias Beacon.Content.ComponentSlot

  @categories [:data, :element, :media]

  @type t :: %__MODULE__{}

  schema "beacon_components" do
    field :site, Beacon.Types.Site
    field :name, :string
    # FIXME: add component description
    # field :description, :string
    field :body, :string
    field :template, :string
    field :example, :string
    field :category, Ecto.Enum, values: @categories, default: :element
    field :thumbnail, :string

    has_many :attrs, ComponentAttr, on_replace: :delete
    has_many :slots, ComponentSlot, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(component, attrs) do
    component
    |> cast(attrs, [:site, :name, :body, :template, :example, :category, :thumbnail])
    |> validate_required([:site, :name, :template, :example, :category])
    |> validate_format(:name, ~r/^[a-z0-9_!]+$/, message: "can only contain lowercase letters, numbers, and underscores")
    |> cast_assoc(:attrs, with: &ComponentAttr.changeset/2)
    |> cast_assoc(:slots, with: &ComponentSlot.changeset/2)
  end

  def categories, do: @categories
end
