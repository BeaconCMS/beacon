defmodule Beacon.Admin.MediaLibrary.Backend.Repo do
  import Ecto.Changeset

  def send_to_provider(changeset, metadata) do
    attrs = %{file_body: metadata.output}

    changeset
    |> cast(attrs, [:file_body])
    |> validate_required([:file_body])
  end
end
