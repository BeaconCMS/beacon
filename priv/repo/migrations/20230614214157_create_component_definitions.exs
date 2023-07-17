defmodule Beacon.Repo.Migrations.CreateComponentDefinitions do
  use Ecto.Migration

  def change do
    create table(:beacon_component_definitions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :thumbnail, :string, null: false
      add :component_category_id, references(:beacon_component_categories, on_delete: :delete_all, type: :binary_id)

      timestamps()
    end

    create index(:beacon_component_definitions, [:component_category_id])
  end
end
