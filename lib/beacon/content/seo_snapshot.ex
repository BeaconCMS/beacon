defmodule Beacon.Content.SEOSnapshot do
  @moduledoc """
  Stores a point-in-time snapshot of site-wide SEO metrics.

  Snapshots are taken manually from the admin UI (or via `take_seo_snapshot/1`)
  and tracked over time to show SEO health trends.
  """

  use Beacon.Schema

  @type t :: %__MODULE__{}

  schema "beacon_seo_snapshots" do
    field :site, Beacon.Types.Site
    field :snapshot_date, :date
    field :metrics, :map, default: %{}

    timestamps updated_at: false
  end

  @doc false
  def changeset(snapshot \\ %__MODULE__{}, attrs) do
    snapshot
    |> cast(attrs, [:site, :snapshot_date, :metrics])
    |> validate_required([:site, :snapshot_date, :metrics])
    |> unique_constraint([:site, :snapshot_date])
  end
end
