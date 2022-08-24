defmodule Beacon.Repo.Migrations.CreateBeaconPageEvents do
  use Ecto.Migration

  def change do
    create table(:beacon_page_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :text
      add :order, :integer
      add :event_name, :text
      add :page_id, references(:beacon_pages, on_delete: :nothing, type: :binary_id)

      timestamps()
    end

    create index(:beacon_page_events, [:page_id])
  end
end
