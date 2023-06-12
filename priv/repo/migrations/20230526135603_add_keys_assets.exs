defmodule Beacon.Repo.Migrations.AddKeysAssets do
  use Ecto.Migration

  def change do
    alter table(:beacon_assets) do
      add :keys, :map, default: %{}
    end
  end
end
