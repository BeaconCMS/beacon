defmodule Beacon.Repo.Migrations.CreateLayouts do
  use Ecto.Migration

  def change do
    create table(:layouts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text
      add :title, :text
      add :body, :text
      add :meta_tags, :map
      add :stylesheets, {:array, :text}

      timestamps()
    end
  end
end
