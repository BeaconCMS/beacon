defmodule Beacon.Repo.Migrations.CreatePages do
  use Ecto.Migration

  def change do
    create table(:beacon_pages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :meta_tags, :map
      add :path, :text
      add :site, :text
      add :template, :text
      add :pending_template, :text
      add :version, :integer, default: 1
      add :order, :integer, default: 1

      add :layout_id, references(:beacon_layouts, type: :binary_id)
      add :pending_layout_id, references(:beacon_layouts, type: :binary_id)

      timestamps()
    end

    create unique_index(:beacon_pages, [:path, :site])
  end
end
