defmodule Beacon.MediaLibrary.Provider.Repo do
  @moduledoc false
  import Ecto.Changeset

  alias Beacon.MediaLibrary.Asset
  alias Beacon.MediaLibrary.UploadMetadata

  @provider_key "repo"

  def send_to_cdn(metadata) do
    key = key_for(metadata)
    attrs = %{file_body: metadata.output}

    resource =
      metadata.resource
      |> cast(attrs, [:file_body])
      |> validate_required([:file_body])
      |> Asset.keys_changeset(provider_key(), key)

    %{metadata | resource: resource}
  end

  def key_for(metadata) do
    UploadMetadata.key_for(metadata)
  end

  def url_for(asset, _), do: url_for(asset)

  def url_for(asset) do
    routes = Beacon.Loader.fetch_routes_module(asset.site)
    Beacon.apply_mfa(routes, :beacon_asset_url, [asset.file_name])
  end

  def provider_key, do: @provider_key
end
