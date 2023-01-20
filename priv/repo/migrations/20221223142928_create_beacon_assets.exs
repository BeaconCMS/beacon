defmodule Beacon.Repo.Migrations.CreateBeaconAssets do
  use Ecto.Migration

  def change do
    create table(:beacon_assets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text
      add :file_name, :string
      add :file_type, :string
      add :file_body, :binary

      timestamps()
    end
  end
end
