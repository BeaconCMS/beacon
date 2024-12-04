defmodule Beacon.MediaLibrary.Provider.Repo do
  @moduledoc """
  Store assets in the database.

  Files are stored as binaries (BLOB)
  """

  import Ecto.Changeset

  alias Beacon.MediaLibrary.Asset
  alias Beacon.MediaLibrary.UploadMetadata

  @provider_key "repo"

  @doc false
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

  @doc false
  def key_for(metadata) do
    UploadMetadata.key_for(metadata)
  end

  @doc false
  def url_for(asset, _), do: url_for(asset)

  @doc false
  def url_for(asset) do
    routes = Beacon.Loader.fetch_routes_module(asset.site)
    Beacon.apply_mfa(asset.site, routes, :beacon_media_url, [asset.file_name])
  end

  @doc false
  def provider_key, do: @provider_key
end
