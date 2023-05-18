defmodule Beacon.Admin.MediaLibrary.UploadMetadata do
  @moduledoc """
  Metadata passed to page rendering lifecycle.
  """

  defstruct [:site, :config, :allowed_media_types, :path, :name, :media_type, :size, :output]

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          config: Beacon.Config.media_type_config() | nil,
          allowed_media_types: list(),
          path: String.t() | nil,
          name: String.t() | nil,
          media_type: String.t() | nil,
          size: integer() | nil,
          output: any() | nil
        }

  # TODO: https://github.com/BeaconCMS/beacon/pull/239#discussion_r1194160478
  def new(site, path, opts \\ []) do
    config = Beacon.Config.fetch!(site)
    name = Keyword.get(opts, :name, Path.basename(path))
    media_type = Keyword.get(opts, :media_type, media_type_from_name(name))
    size = Keyword.get(opts, :size)
    output = Keyword.get(opts, :output)

    %__MODULE__{
      site: site,
      config: config_for_media_type(config, media_type),
      allowed_media_types: config.allowed_media_types,
      path: path,
      name: name,
      media_type: media_type,
      size: size,
      output: output
    }
  end

  def config_for_media_type(metadata, media_type) do
    metadata.site
    |> Beacon.Config.fetch!()
    |> Beacon.Config.config_for_media_type(media_type)
    |> Enum.into(%{})
  end

  defp media_type_from_name(name) do
    name
    |> Path.extname()
    |> String.replace_leading(".", "")
    |> MIME.type()
  end
end
