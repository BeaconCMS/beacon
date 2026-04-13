defmodule Beacon.Content.Author do
  @moduledoc """
  Represents a content author for a Beacon site.

  Authors are linked to pages via `author_id` and their information is used
  to generate `Person` JSON-LD structured data for E-E-A-T signals.
  """

  use Beacon.Schema

  @type t :: %__MODULE__{}

  schema "beacon_authors" do
    field :site, Beacon.Types.Site
    field :name, :string
    field :slug, :string
    field :bio, :string
    field :job_title, :string
    field :avatar_url, :string
    field :credentials, :string
    field :same_as, {:array, :string}, default: []

    timestamps()
  end

  @doc false
  def changeset(author \\ %__MODULE__{}, attrs) do
    author
    |> cast(attrs, [:site, :name, :slug, :bio, :job_title, :avatar_url, :credentials, :same_as])
    |> validate_required([:site, :name, :slug])
    |> validate_format(:slug, ~r/^[a-z0-9\-]+$/, message: "must be lowercase with hyphens only")
    |> unique_constraint([:site, :slug])
  end
end
