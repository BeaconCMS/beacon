defmodule Beacon.Repo.Migrations.AddStructNameToBeaconComponentAttrs do
  use Ecto.Migration

  def change do
    alter table(:beacon_component_attrs) do
      add :struct_name, :string
    end
  end
end
