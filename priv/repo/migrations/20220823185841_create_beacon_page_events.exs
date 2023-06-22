defmodule Beacon.Repo.Migrations.CreateBeaconPageEvents do
  use Ecto.Migration

  def up do
    create table(:beacon_page_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :text, null: false
      add :order, :integer, null: false
      add :event_name, :text, null: false
      add :page_id, references(:beacon_pages, on_delete: :nothing, type: :binary_id)

      timestamps()
    end

    create index(:beacon_page_events, [:page_id])
  end

  def down do
  end
end
