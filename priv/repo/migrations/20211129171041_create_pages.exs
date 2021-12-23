defmodule Beacon.Repo.Migrations.CreatePages do
  use Ecto.Migration

  def change do
    create table(:pages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :path, :text
      add :site, :text
      add :template, :text
      add :pending_template, :text
      add :version, :integer, default: 1

      add :layout_id, references(:layouts, type: :binary_id)
      add :pending_layout_id, references(:layouts, type: :binary_id)

      timestamps()
    end

    create unique_index(:pages, [:path, :site])
  end
end
