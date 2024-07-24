defmodule Beacon.MediaLibrary.Provider.S3 do
  @moduledoc false
  alias Beacon.MediaLibrary.Asset
  alias Beacon.MediaLibrary.UploadMetadata

  @provider_key "s3"
  @s3_buffer_size 5 * 1024 * 1024

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

  def key_for(metadata) do
    UploadMetadata.key_for(metadata)
  end

  def bucket do
    case ExAws.Config.new(:s3) do
      %{bucket: bucket} -> bucket
      _ -> raise ArgumentError, message: "Missing :ex_aws, :s3, bucket: \"...\" configuration"
    end
  end

  def list do
    ExAws.S3.list_objects(bucket()) |> ExAws.request!()
  end

  def url_for(asset, config \\ []) do
    key = Map.fetch!(asset.keys, provider_key())
    Path.join(host(config), key)
  end

  defp host([]) do
    host(ExAws.Config.new(:s3))
  end

  defp host(%{bucket: bucket, host: host} = config) do
    scheme = Map.get(config, :scheme, "https://")
    "#{scheme}#{bucket}.#{host}"
  end

  defp host(_) do
    raise(
      ArgumentError,
      message: "Missing :ex_aws, :s3, bucket: \"...\" or host: \" ...\" configuration"
    )
  end

  def provider_key, do: @provider_key
end
