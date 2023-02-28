defmodule Beacon.Repo.Migrations.AddDescriptionToPages do
  use Ecto.Migration

  def change do
    alter table(:beacon_pages) do
      add :description, :text
    end
  end
end
