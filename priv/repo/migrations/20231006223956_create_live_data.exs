defmodule Beacon.Repo.Migrations.CreateLiveData do
  use Ecto.Migration

  def change do
    create table(:beacon_live_data, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :path, :text, null: false
      add :assign, :text, null: false
      add :code, :text, null: false
      add :format, :string, null: false

      timestamps()
    end

    create index(:beacon_live_data, [:site])
  end
end
