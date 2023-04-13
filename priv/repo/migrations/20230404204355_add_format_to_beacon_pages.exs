defmodule Beacon.Repo.Migrations.AddFormatToBeaconPages do
  use Ecto.Migration

  def up do
    alter table(:beacon_pages) do
      add :format, :text, default: "heex"
    end

    execute "UPDATE beacon_pages SET format = 'heex'"

    alter table(:beacon_pages) do
      modify :format, :text, null: false
    end
  end

  def down do
    alter table(:beacon_pages) do
      remove :format, :text
    end
  end
end
