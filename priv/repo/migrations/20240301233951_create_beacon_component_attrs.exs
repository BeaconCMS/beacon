defmodule Beacon.Repo.Migrations.CreateBeaconComponentAttrs do
  use Ecto.Migration

  def change do
    create table(:beacon_component_attrs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :type, :string, null: false
      add :opts, {:array, :map}, default: []

      add :component_id, references(:beacon_components, on_delete: :delete_all, type: :binary_id),
        null: false

      timestamps()
    end

    create index(:beacon_component_attrs, [:component_id])
  end
end
