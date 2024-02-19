defmodule Beacon.Repo.Migrations.CreatePageSnapshots do
  use Ecto.Migration

  def change do
    create table(:beacon_page_snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :schema_version, :integer, null: false, comment: "data structure version"
      add :site, :text, null: false
      add :page, :binary, null: false

      add :page_id, references(:beacon_pages, on_delete: :delete_all, type: :binary_id),
        null: false

      add :event_id, references(:beacon_page_events, on_delete: :delete_all, type: :binary_id)
      timestamps(updated_at: false, type: :utc_datetime_usec)
    end
  end
end
