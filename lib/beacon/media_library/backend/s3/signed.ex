defmodule Beacon.MediaLibrary.Backend.S3.Signed do
  alias Beacon.MediaLibrary.Backend.S3

  defdelegate send_to_cdn(metadata, config \\ []), to: S3
  defdelegate key_for(metadata), to: S3
  defdelegate bucket(), to: S3
  defdelegate list(), to: S3
  defdelegate backend_key(), to: S3

  def url_for(asset, config \\ []) do
    key = Map.fetch!(asset.keys, backend_key())
    config = ExAws.Config.new(:s3, config)
    bucket = config.bucket

    {:ok, url} = ExAws.S3.presigned_url(config, :get, bucket, key)
    url
  end
end
