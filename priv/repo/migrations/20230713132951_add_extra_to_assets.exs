defmodule Beacon.Repo.Migrations.AddExtraToAssets do
  use Ecto.Migration

  def change do
    alter table(:beacon_assets) do
      add :extra, :map, default: %{}, null: false
    end
  end
end
