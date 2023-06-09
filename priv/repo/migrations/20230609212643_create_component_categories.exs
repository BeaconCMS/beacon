defmodule Beacon.Repo.Migrations.CreateComponentCategories do
  use Ecto.Migration

  def change do
    create table(:beacon_component_categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, size: 40
      timestamps()
    end
  end
end
