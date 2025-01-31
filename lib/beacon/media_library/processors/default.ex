defmodule Beacon.MediaLibrary.Processors.Default do
  @moduledoc false
  alias Beacon.MediaLibrary.UploadMetadata

  def process!(%UploadMetadata{} = metadata) do
    output = Beacon.MediaLibrary.read_binary!(metadata)

    config = UploadMetadata.config_for_media_type(metadata, metadata.media_type)

    size = byte_size(output)

    %{metadata | output: output, config: config, size: size}
  end
end
