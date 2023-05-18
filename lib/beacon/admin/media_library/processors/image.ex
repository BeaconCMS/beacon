defmodule Beacon.Admin.MediaLibrary.Processors.Image do
  alias Beacon.Admin.MediaLibrary.UploadMetadata

  def process!(%UploadMetadata{} = metadata) do
    # TODO revisit this. Should be configurable?
    target_file_type = ".webp"

    output =
      metadata.path
      |> Image.open!(access: :random)
      |> Image.write!(:memory, suffix: target_file_type)

    name = rename_to_target_file_type(metadata.name, target_file_type)

    media_type = target_file_type |> String.replace_leading(".", "") |> MIME.type()
    config = UploadMetadata.config_for_media_type(metadata, media_type)

    %{metadata | output: output, name: name, config: config, media_type: media_type}
  end

  defp rename_to_target_file_type(name, target_file_type) do
    ext = Path.extname(name)
    String.replace(name, ext, target_file_type)
  end
end
