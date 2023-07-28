defmodule Beacon.MediaLibrary.Processors.Default do
  alias Beacon.MediaLibrary.UploadMetadata

  def process!(%UploadMetadata{} = metadata) do
    output = File.read!(metadata.path)

    config = UploadMetadata.config_for_media_type(metadata, metadata.media_type)

    size = byte_size(output)

    %{metadata | output: output, config: config, size: size}
  end
end
