defmodule Beacon.Repo.Migrations.AddRawSchemaToPages do
  use Ecto.Migration

  def change do
    alter table(:beacon_pages) do
      add :raw_schema, {:array, :map}, default: []
    end
  end
end
