defmodule Beacon.Admin.MediaLibrary.Asset do
  use Ecto.Schema
  import Ecto.Changeset

  alias Beacon.Admin.MediaLibrary.Backend

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_assets" do
    field :file_body, :binary
    field :file_name, :string
    field :media_type, :string
    field :site, Beacon.Types.Atom
    field :deleted_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(asset, attrs) do
    asset
    |> cast(attrs, [:site, :file_name, :media_type, :file_body])
    |> validate_required([:site, :file_name, :media_type, :file_body])
  end

  @doc false
  def upload_changeset(asset, metadata) do
    metadata = Backend.process!(metadata)

    attrs = %{
      site: metadata.site,
      file_name: metadata.name,
      media_type: metadata.media_type
    }

    asset
    |> cast(attrs, [:site, :file_name, :media_type])
    |> validate_required([:site, :file_name, :media_type])
    |> Backend.validate_for_delivery(metadata)
    |> Backend.send_to_providers(metadata)
  end
end
