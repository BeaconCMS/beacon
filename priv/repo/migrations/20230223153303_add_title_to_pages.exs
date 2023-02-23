defmodule Beacon.Repo.Migrations.AddTitleToPages do
  use Ecto.Migration

  def change do
    alter table(:beacon_pages) do
      add :title, :text
    end
  end
end
