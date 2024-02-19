defmodule Beacon.Repo.Migrations.CreatePageVariants do
  use Ecto.Migration

  def change do
    create table(:page_variants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false
      add :template, :text, null: false
      add :weight, :integer, null: false

      add :page_id, references(:beacon_pages, on_delete: :delete_all, type: :binary_id),
        null: false

      timestamps()
    end

    create index(:page_variants, [:page_id])
  end
end
