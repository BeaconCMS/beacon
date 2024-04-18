defmodule Beacon.Repo.Migrations.CreateBeaconSlotAttrs do
  use Ecto.Migration

  def change do
    create table(:beacon_slot_attrs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :type, :string, null: false
      add :opts, :binary

      add :slot_id,
          references(:beacon_component_slots, on_delete: :delete_all, type: :binary_id),
          null: false

      timestamps()
    end

    create index(:beacon_slot_attrs, [:slot_id])
  end
end
