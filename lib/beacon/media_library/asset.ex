defmodule Beacon.MediaLibrary.Asset do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "beacon_assets" do
    field :file_body, :binary
    field :file_name, :string
    field :file_type, :string
    field :site, :string
    field :deleted_at, :utc_datetime

    timestamps()
  end
end
