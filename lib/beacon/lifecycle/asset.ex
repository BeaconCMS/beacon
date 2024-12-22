defmodule Beacon.Lifecycle.Asset do
  @moduledoc false

  alias Beacon.Lifecycle
  alias Beacon.MediaLibrary
  alias Beacon.MediaLibrary.Processors
  alias Beacon.MediaLibrary.Provider

  @behaviour Beacon.Lifecycle

  @impl Lifecycle
  def validate_output!(%Lifecycle{output: %MediaLibrary.Asset{}} = lifecycle, _config, _sub_key), do: lifecycle

  def validate_output!(lifecycle, _config, _sub_key) do
    raise Beacon.LoaderError, """
    Return output must be of type Beacon.MediaLibrary.Asset

    Output returned for lifecycle: #{lifecycle.name}
    #{inspect(lifecycle.output)}
    """
  end

  @impl Lifecycle
  def put_metadata(lifecycle, _config, metadata) do
    %{lifecycle | metadata: metadata}
  end

  @doc """
  Execute all steps for stage `:upload_asset`.

  It's executed in the same repo transaction, after the `asset` record is saved into the database.
  """
  @spec upload_asset(MediaLibrary.UploadMetadata.t(), Ecto.Schema.t()) :: Ecto.Schema.t()
  def upload_asset(metadata, asset) do
    lifecycle = Lifecycle.execute(__MODULE__, metadata.site, :upload_asset, asset, context: metadata)
    lifecycle.output
  end

  def thumbnail(asset, %MediaLibrary.UploadMetadata{media_type: "image/webp"} = metadata) do
    Processors.Image.thumbnail!(asset, metadata)
    {:cont, asset}
  end

  def thumbnail(asset, _metadata), do: {:cont, asset}

  def variant_480w(asset, %MediaLibrary.UploadMetadata{media_type: "image/webp"} = metadata) do
    Processors.Image.variant_480w!(asset, metadata)
    {:cont, asset}
  end

  def variant_480w(asset, _metadata), do: {:cont, asset}

  def delete_uploaded_asset(%MediaLibrary.Asset{site: site, media_type: media_type} = asset) do
    config =
      site
      |> Beacon.Config.fetch!()
      |> Beacon.Config.config_for_media_type(media_type)
      |> Enum.into(%{})

    Provider.soft_delete(asset, config)

    {:cont, asset}
  end
end
