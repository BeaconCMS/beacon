defmodule Beacon.Migrations.V002 do
  use Ecto.Migration

  def up do
    alter table(:beacon_component_attrs) do
      add :struct_name, :string
    end

    alter table(:beacon_component_slot_attrs) do
      add :struct_name, :string
    end
  end

  def down do
    alter table(:beacon_component_attrs) do
      remove_if_exists :struct_name, :string
    end

    alter table(:beacon_component_slot_attrs) do
      remove_if_exists :struct_name, :string
    end
  end
end
