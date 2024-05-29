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

  @categories [:nav, :header, :sign_in, :sign_up, :stats, :footer, :basic, :other]

  @type t :: %__MODULE__{}

  schema "beacon_components" do
    field :site, Beacon.Types.Site
    field :name, :string
    field :template, :string
    field :category, Ecto.Enum, values: @categories, default: :other
    field :thumbnail, :string

    has_many :attrs, ComponentAttr, on_replace: :delete
    has_many :slots, ComponentSlot, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(component, attrs) do
    component
    |> cast(attrs, [:site, :name, :template, :category, :thumbnail])
    |> validate_required([:site, :name, :template, :category])
    |> cast_assoc(:attrs, with: &ComponentAttr.changeset/2)
    |> cast_assoc(:slots, with: &ComponentSlot.changeset/2)
  end

  def categories, do: @categories
end
