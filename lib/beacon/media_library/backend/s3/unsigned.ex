defmodule Beacon.MediaLibrary.Provider.S3.Unsigned do
  @moduledoc false
  alias Beacon.MediaLibrary.Provider.S3

  defdelegate send_to_cdn(metadata, config \\ []), to: S3
  defdelegate key_for(metadata), to: S3
  defdelegate bucket(), to: S3
  defdelegate list(), to: S3
  defdelegate url_for(asset, config \\ []), to: S3
  defdelegate provider_key(), to: S3
end
