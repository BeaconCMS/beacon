defmodule Beacon.Admin.MediaLibrary.Processors.Default do
  alias Beacon.Admin.MediaLibrary.UploadMetadata

  def process!(%UploadMetadata{} = metadata) do
    ext = Path.extname(metadata.name)

    output =
      metadata.path
      |> Image.open!(access: :random)
      |> Image.write!(:memory, suffix: ext)

    config = UploadMetadata.config_for_media_type(metadata, metadata.media_type)
    size = byte_size(output)

    %{metadata | output: output, config: config, size: size}
  end
end
