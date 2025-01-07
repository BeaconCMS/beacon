defmodule Beacon.MediaLibrary.UploadMetadata do
  @moduledoc """
  Metadata passed to page rendering lifecycle.
  """

  alias Beacon.MediaLibrary.Asset
  alias Beacon.MediaTypes

  defstruct [:site, :config, :allowed_media_accept_types, :path, :name, :media_type, :size, :output, :resource, :node, :extra]

  @type t :: %__MODULE__{
          site: Beacon.Types.Site.t(),
          config: Beacon.Config.media_type_config() | nil,
          allowed_media_accept_types: list(),
          path: String.t() | nil,
          name: String.t() | nil,
          media_type: String.t() | nil,
          size: integer() | nil,
          output: any(),
          resource: Ecto.Changeset.t(%Asset{}),
          node: Node.t(),
          extra: map() | nil
        }

  # TODO: https://github.com/BeaconCMS/beacon/pull/239#discussion_r1194160478
  @doc false
  def new(site, path, node, opts \\ []) do
    opts =
      Keyword.reject(opts, fn
        {_, ""} -> true
        _ -> false
      end)

    config = Beacon.Config.fetch!(site)
    name = Keyword.get(opts, :name, Path.basename(path))

    media_type =
      opts
      |> Keyword.get(:media_type, media_type_from_name(name))
      |> MediaTypes.normalize()

    size =
      Keyword.get_lazy(opts, :size, fn ->
        case Beacon.MediaLibrary.file_stat(path, node) do
          {:ok, stat} -> stat.size
          _ -> nil
        end
      end)

    output = Keyword.get(opts, :output)
    resource = Keyword.get(opts, :resource, Asset.bare_changeset())
    extra = Keyword.get(opts, :extra)

    %__MODULE__{
      site: site,
      config: config_for_media_type(config, media_type),
      allowed_media_accept_types: config.allowed_media_accept_types,
      path: path,
      name: name,
      media_type: media_type,
      size: size,
      output: output,
      resource: resource,
      node: node,
      extra: extra
    }
  end

  @doc false
  def config_for_media_type(metadata, media_type) do
    metadata.site
    |> Beacon.Config.fetch!()
    |> Beacon.Config.config_for_media_type(media_type)
    |> Enum.into(%{})
  end

  @doc false
  def key_for(%{name: name, site: site}) do
    ext = Path.extname(name)

    basename =
      name
      |> Path.basename()
      |> String.replace_suffix(ext, "")
      |> clean()

    ext =
      ext
      |> String.replace(".", "")
      |> clean()

    "#{site}/#{basename}.#{ext}"
  end

  defp clean(str) do
    downcased = String.downcase(str)
    dashed = Regex.replace(~r/[[:space:]\._]/u, downcased, "-")
    Regex.replace(~r/[^[:alnum:]-]/u, dashed, "")
  end

  defp media_type_from_name(name) do
    name
    |> Path.extname()
    |> String.replace_leading(".", "")
    |> MIME.type()
  end
end
