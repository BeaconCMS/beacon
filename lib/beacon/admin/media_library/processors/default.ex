defmodule Beacon.Admin.MediaLibrary.Processors.Default do
  alias Beacon.Admin.MediaLibrary.UploadMetadata

  def process!(%UploadMetadata{} = metadata) do
    metadata
  end
end
