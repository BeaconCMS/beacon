defmodule Beacon.MediaLibrary.Provider do
  @moduledoc """

  """

  alias Beacon.MediaLibrary.UploadMetadata

  @doc false
  def process!(%UploadMetadata{} = metadata) do
    metadata.config.processor.(metadata)
  end

  @doc false
  @spec validate_for_delivery(UploadMetadata.t()) :: UploadMetadata.t()
  def validate_for_delivery(%UploadMetadata{} = metadata) do
    Enum.reduce(metadata.config.validations, metadata, fn
      validation, md -> validation.(md)
    end)
  end

  @doc false
  @spec validate_for_delivery({UploadMetadata.t(), any()}) :: UploadMetadata.t()
  def validate_for_delivery({%UploadMetadata{} = metadata, config}) do
    Enum.reduce(metadata.config.validations, metadata, fn
      validation, md -> validation.(md, config)
    end)
  end

  @doc false
  @spec send_to_cdns(UploadMetadata.t()) :: UploadMetadata.t()
  def send_to_cdns(%UploadMetadata{} = metadata) do
    Enum.reduce(metadata.config.providers, metadata, fn
      provider, md -> provider.send_to_cdn(md)
    end)
  end

  @doc false
  @spec send_to_cdns({UploadMetadata.t(), any()}) :: UploadMetadata.t()
  def send_to_cdns({%UploadMetadata{} = metadata, config}) do
    Enum.reduce(metadata.config.providers, metadata, fn
      provider, md -> provider.send_to_cdn(md, config)
    end)
  end
end
