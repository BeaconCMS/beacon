defmodule Beacon.Repo.Migrations.AddVariantFields do
  use Ecto.Migration

  def change do
    alter table(:beacon_assets) do
      add :source_id, references(:beacon_assets, type: :binary_id)
      add :usage_tag, :text
    end

    create index(:beacon_assets, [:source_id])
    create index(:beacon_assets, [:usage_tag])
  end
end
