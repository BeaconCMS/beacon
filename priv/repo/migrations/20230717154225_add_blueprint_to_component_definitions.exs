defmodule Beacon.Repo.Migrations.AddBlueprintToComponentDefinitions do
  use Ecto.Migration

  def change do
    alter table(:beacon_component_definitions) do
      add :blueprint, :map, default: %{}
    end
  end
end
