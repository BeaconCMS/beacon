defmodule Beacon.Lifecycle.Asset do
  alias Beacon.Admin.MediaLibrary
  alias Beacon.Admin.MediaLibrary.Processors
  alias Beacon.Lifecycle

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
    Processors.Image.thumbnail!(metadata)
    {:cont, asset}
  end

  def thumbnail(asset, _metadata), do: {:cont, asset}
end
