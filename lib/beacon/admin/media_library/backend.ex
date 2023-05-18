defmodule Beacon.Admin.MediaLibrary.Backend do
  alias Beacon.Admin.MediaLibrary.UploadMetadata

  def process!(%UploadMetadata{} = metadata) do
    metadata.config.processor.(metadata)
  end

  @spec validate_for_delivery(Ecto.Changeset.t(), Beacon.Admin.MediaLibrary.UploadMetadata.t()) :: Ecto.Changeset.t()
  def validate_for_delivery(%Ecto.Changeset{} = changeset, %UploadMetadata{} = metadata) do
    Enum.reduce(metadata.config.validations, changeset, fn validation, cs -> validation.(cs, metadata) end)
  end

  @spec send_to_providers(Ecto.Changeset.t(), Beacon.Admin.MediaLibrary.UploadMetadata.t()) :: Ecto.Changeset.t()
  def send_to_providers(%Ecto.Changeset{} = changeset, %UploadMetadata{} = metadata) do
    Enum.reduce(metadata.config.backends, changeset, fn backend, cs -> backend.send_to_provider(cs, metadata) end)
  end
end
