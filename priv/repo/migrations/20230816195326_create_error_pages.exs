defmodule Beacon.Repo.Migrations.CreateErrorPages do
  use Ecto.Migration

  def change do
    create table(:beacon_error_pages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :status, :integer, null: false
      add :template, :text, null: false
      add :layout_id, references(:beacon_layouts, type: :binary_id)

      timestamps()
    end

    create index(:beacon_error_pages, [:site, :status])
  end
end
