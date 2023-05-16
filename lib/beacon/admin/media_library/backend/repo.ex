defmodule Beacon.Admin.MediaLibrary.Backend.Repo do
  Beacon.Admin.MediaLibrary.Backend.Repo
  import Ecto.Changeset

  def validate_for_delivery(changeset, metadata) do
    Enum.reduce(metadata.config.validations, changeset, fn validation, cs -> validation.(cs, metadata) end)
  end

  def send_to_provider(changeset, metadata) do
    attrs = %{file_body: File.read!(metadata.path)}

    changeset
    |> cast(attrs, [:file_body])
    |> validate_required([:file_body])
  end
end
