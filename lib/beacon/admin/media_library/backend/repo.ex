defmodule Beacon.Admin.MediaLibrary.Backend.Repo do
  import Ecto.Changeset

  def send_to_cdn(metadata) do
    attrs = %{file_body: metadata.output}

    resource =
      metadata.resource
      |> cast(attrs, [:file_body])
      |> validate_required([:file_body])

    %{metadata | resource: resource}
  end
end
