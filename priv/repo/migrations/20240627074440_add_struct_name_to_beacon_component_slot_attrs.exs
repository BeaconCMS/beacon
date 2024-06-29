defmodule Beacon.Repo.Migrations.AddStructNameToBeaconComponentSlotAttrs do
  use Ecto.Migration

  def change do
    alter table(:beacon_component_slot_attrs) do
      add :struct_name, :string
    end
  end
end
