defmodule Beacon.Repo.Migrations.CreateLayoutSnapshots do
  use Ecto.Migration

  def change do
    create table(:beacon_layout_snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :schema_version, :integer, null: false, comment: "data structure version"
      add :site, :text, null: false
      add :layout, :binary, null: false

      add :layout_id, references(:beacon_layouts, on_delete: :delete_all, type: :binary_id),
        null: false

      add :event_id, references(:beacon_layout_events, on_delete: :delete_all, type: :binary_id)
      timestamps(updated_at: false, type: :utc_datetime_usec)
    end
  end
end
