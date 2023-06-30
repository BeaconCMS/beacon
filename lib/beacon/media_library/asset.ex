defmodule Beacon.MediaLibrary.Asset do
  @moduledoc false

  use Beacon.Schema
  @derive BeaconWeb.Cache.Stale

  schema "beacon_assets" do
    field :file_body, :binary
    field :file_name, :string
    field :media_type, :string
    field :site, Beacon.Types.Site
    field :deleted_at, :utc_datetime

    timestamps()
  end
end
