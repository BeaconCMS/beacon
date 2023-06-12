defmodule Beacon.Admin.MediaLibrary.Backend.S3.Unsigned do
  alias Beacon.Admin.MediaLibrary.Backend.S3

  defdelegate send_to_cdn(metadata, config \\ []), to: S3
  defdelegate key_for(metadata), to: S3
  defdelegate bucket(), to: S3
  defdelegate list(), to: S3
  defdelegate url_for(asset, config \\ []), to: S3
  defdelegate backend_key(), to: S3
end
