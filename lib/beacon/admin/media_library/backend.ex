defmodule Beacon.Admin.MediaLibrary.Backend do
  def validate_for_delivery(changeset, metadata) do
    Enum.reduce(metadata.config.backends, changeset, fn backend, cs -> backend.validate_for_delivery(cs, metadata) end)
  end

  def send_to_providers(changeset, metadata) do
    Enum.reduce(metadata.config.backends, changeset, fn backend, cs -> backend.send_to_provider(cs, metadata) end)
  end
end
