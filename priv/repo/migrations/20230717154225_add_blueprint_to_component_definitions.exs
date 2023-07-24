defmodule Beacon.Repo.Migrations.AddBlueprintToComponentDefinitions do
  use Ecto.Migration

  def change do
    alter table(:beacon_component_definitions) do
      add :blueprint, :text
    end
  end
end
