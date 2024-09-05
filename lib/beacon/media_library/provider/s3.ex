defmodule Beacon.MediaLibrary.Provider.S3 do
  @moduledoc """
  Store assets in S3 using the `ex_aws` library.

  All files are stored in the same bucket under the same level.

  """

  alias Beacon.MediaLibrary.Asset
  alias Beacon.MediaLibrary.UploadMetadata

  @provider_key "s3"
  @s3_buffer_size 5 * 1024 * 1024

  @doc false
  def send_to_cdn(metadata, config \\ []) do
    key = key_for(metadata)

    StringIO.open(metadata.output, [], fn pid ->
      IO.binstream(pid, @s3_buffer_size)
      |> ExAws.S3.upload(bucket(), key)
      |> ExAws.request!(config)
    end)

    change = Asset.keys_changeset(metadata.resource, provider_key(), key)
    %{metadata | resource: change}
  end

  @doc false
  def key_for(metadata) do
    UploadMetadata.key_for(metadata)
  end

  @doc false
  def bucket do
    case ExAws.Config.new(:s3) do
      %{bucket: bucket} -> bucket
      _ -> raise ArgumentError, message: "Missing :ex_aws, :s3, bucket: \"...\" configuration"
    end
  end

  @doc false
  def list do
    ExAws.S3.list_objects(bucket()) |> ExAws.request!()
  end

  @doc false
  def url_for(asset, config \\ []) do
    key = Map.fetch!(asset.keys, provider_key())
    Path.join(host(config), key)
  end

  @doc false
  defp host([]) do
    host(ExAws.Config.new(:s3))
  end

  @doc false
  defp host(%{bucket: bucket, host: host} = config) do
    scheme = Map.get(config, :scheme, "https://")
    "#{scheme}#{bucket}.#{host}"
  end

  @doc false
  defp host(_) do
    raise(
      ArgumentError,
      message: "Missing :ex_aws, :s3, bucket: \"...\" or host: \" ...\" configuration"
    )
  end

  @doc false
  def provider_key, do: @provider_key
end
