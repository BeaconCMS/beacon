defmodule Beacon.MediaLibrary.Processors.Image do
  alias Beacon.MediaLibrary
  alias Beacon.MediaLibrary.UploadMetadata

  @thumbnail_size 200

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
    size = byte_size(output)

    %{metadata | output: output, name: name, config: config, media_type: media_type, size: size}
  end

  defp rename_to_target_file_type(name, target_file_type) do
    ext = Path.extname(name)
    String.replace_trailing(name, ext, target_file_type)
  end

  def thumbnail!(%UploadMetadata{} = metadata) do
    metadata
    |> create_thumbnail()
    |> MediaLibrary.send_to_cdns()
    |> MediaLibrary.save_asset!()

    metadata
  end

  def create_thumbnail(metadata) do
    name = append_to_filename(metadata.name, "thumb")
    ext = Path.extname(name)

    output =
      metadata.output
      |> Image.open!()
      |> Image.thumbnail!(@thumbnail_size, crop: :attention)
      |> Image.write!(:memory, suffix: ext)

    name = append_to_filename(metadata.name, "thumb")
    size = byte_size(output)
    %{metadata | output: output, name: name, size: size}
  end

  defp append_to_filename(name, tag) do
    ext = Path.extname(name)
    String.replace_trailing(name, ext, "-#{tag}#{ext}")
  end
end
