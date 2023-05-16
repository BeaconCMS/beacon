defmodule Beacon.Admin.MediaLibrary.FileMetadata do
  @moduledoc """
  Metadata passed to page rendering lifecycle.
  """

  defstruct [:site, :config, :allowed_media_types, :path, :name, :media_type, :size]

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          config: list(),
          allowed_media_types: list(),
          path: String.t() | nil,
          name: String.t() | nil,
          media_type: String.t() | nil,
          size: integer() | nil
        }

  # TODO: https://github.com/BeaconCMS/beacon/pull/239#discussion_r1194160478
  def new(site, path, name, media_type, size) do
    config = Beacon.Config.fetch!(site)

    asset_config =
      config
      |> Beacon.Config.config_for_media_type(media_type)
      |> Enum.into(%{})

    %__MODULE__{
      site: site,
      config: asset_config,
      allowed_media_types: config.allowed_media_types,
      path: path,
      name: name,
      media_type: media_type,
      size: size
    }
  end
end
