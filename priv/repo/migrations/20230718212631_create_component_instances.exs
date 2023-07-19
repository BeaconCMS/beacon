defmodule Beacon.Repo.Migrations.CreateComponentInstances do
  use Ecto.Migration

  def change do
    create table(:beacon_component_instances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :data, :map, default: %{}

      timestamps()
    end
  end
end
