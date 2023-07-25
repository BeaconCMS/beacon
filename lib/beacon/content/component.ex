defmodule Beacon.Content.Component do
  @categories [:nav, :header, :sign_in, :sign_up, :stats, :footer, :basic]
  def categories, do: @categories

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

  @type t :: %__MODULE__{}

  schema "beacon_components" do
    field :body, :string
    field :name, :string
    field :thumbnail, :string
    field :site, Beacon.Types.Site
    field :category, Ecto.Enum, values: @categories

    timestamps()
  end

  @doc false
  def changeset(component, attrs) do
    component
    |> cast(attrs, [:site, :name, :thumbnail, :body, :category])
    |> validate_required([:site, :name, :body, :category])
  end
end
