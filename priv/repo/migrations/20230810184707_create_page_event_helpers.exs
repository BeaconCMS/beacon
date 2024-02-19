defmodule Beacon.Repo.Migrations.CreatePageEventHelpers do
  use Ecto.Migration

  def change do
    create table(:beacon_page_event_handlers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false
      add :code, :text, null: false

      add :page_id, references(:beacon_pages, on_delete: :delete_all, type: :binary_id),
        null: false

      timestamps()
    end

    create index(:beacon_page_event_handlers, [:page_id])
  end
end
