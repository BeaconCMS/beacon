defmodule Beacon.CSS.Manifest do
  @moduledoc """
  Ecto schema for CSS manifest records.

  Tracks the current compiled CSS hash and S3 storage key for each site,
  enabling the warm tier (S3) of the three-tier CSS storage system.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:site, :string, autogenerate: false}
  schema "beacon_css_manifests" do
    field :hash, :string
    field :s3_key, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(manifest, attrs) do
    manifest
    |> cast(attrs, [:site, :hash, :s3_key])
    |> validate_required([:site, :hash, :s3_key])
  end
end
