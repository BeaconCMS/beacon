defmodule Beacon.Repo.Migrations.CreateLayoutEvents do
  use Ecto.Migration

  def change do
    create table(:beacon_layout_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false

      add :layout_id, references(:beacon_layouts, on_delete: :delete_all, type: :binary_id),
        null: false

      add :event, :text, null: false
      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create constraint(:beacon_layout_events, :event,
             check: "event = 'created' or event = 'published'"
           )
  end
end
