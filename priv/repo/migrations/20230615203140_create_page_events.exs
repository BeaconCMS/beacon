defmodule Beacon.Repo.Migrations.CreatePageEvents do
  use Ecto.Migration

  def change do
    create table(:beacon_page_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false

      add :page_id, references(:beacon_pages, on_delete: :delete_all, type: :binary_id),
        null: false

      add :event, :text, null: false
      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create constraint(:beacon_page_events, :event,
             check: "event = 'created' or event = 'published' or event = 'unpublished'"
           )
  end
end
