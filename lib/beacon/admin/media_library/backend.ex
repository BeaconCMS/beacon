defmodule Beacon.Admin.MediaLibrary.Backend do
  alias Beacon.Admin.MediaLibrary.UploadMetadata

  def process!(%UploadMetadata{} = metadata) do
    metadata.config.processor.(metadata)
  end

  @spec validate_for_delivery(Beacon.Admin.MediaLibrary.UploadMetadata.t()) :: Beacon.Admin.MediaLibrary.UploadMetadata.t()
  def validate_for_delivery(%UploadMetadata{} = metadata) do
    Enum.reduce(metadata.config.validations, metadata, fn
      validation, {md, config} -> validation.(md, config)
      validation, md -> validation.(md)
    end)
  end

  @spec send_to_cdns(Beacon.Admin.MediaLibrary.UploadMetadata.t()) :: Beacon.Admin.MediaLibrary.UploadMetadata.t()
  def send_to_cdns(%UploadMetadata{} = metadata) do
    Enum.reduce(metadata.config.backends, metadata, fn
      backend, {md, config} -> backend.send_to_cdn(md, config)
      backend, md -> backend.send_to_cdn(md)
    end)
  end
end
