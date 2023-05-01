defmodule Beacon.Repo.Migrations.AddExtraToPages do
  use Ecto.Migration

  def change do
    alter table(:beacon_pages) do
      add :extra, :map, default: %{}
    end
  end
end
