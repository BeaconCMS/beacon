defmodule Beacon.MediaLibrary.Backend.Repo do
  import Ecto.Changeset

  alias Beacon.MediaLibrary.Asset
  alias Beacon.MediaLibrary.UploadMetadata

  @backend_key "repo"

  def send_to_cdn(metadata) do
    key = key_for(metadata)
    attrs = %{file_body: metadata.output}

    resource =
      metadata.resource
      |> cast(attrs, [:file_body])
      |> validate_required([:file_body])
      |> Asset.keys_changeset(backend_key(), key)

    %{metadata | resource: resource}
  end

  def key_for(metadata) do
    UploadMetadata.key_for(metadata)
  end

  def url_for(asset, _), do: url_for(asset)

  def url_for(asset) do
    Beacon.Router.beacon_asset_url(asset.site, asset.file_name)
  end

  def backend_key, do: @backend_key
end
