defmodule Beacon.Repo.Migrations.CreateLiveDataAssigns do
  use Ecto.Migration

  def change do
    create table(:beacon_live_data_assigns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :text, null: false
      add :value, :text, null: false
      add :format, :string, null: false

      add :live_data_id, references(:beacon_live_data, on_delete: :delete_all, type: :binary_id),
        null: false

      timestamps()
    end

    create index(:beacon_live_data_assigns, [:live_data_id])
  end
end
