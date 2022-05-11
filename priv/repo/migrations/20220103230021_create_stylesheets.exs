defmodule Beacon.Repo.Migrations.CreateStylesheets do
  use Ecto.Migration

  def change do
    create table(:beacon_stylesheets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :content, :text
      add :site, :string

      timestamps()
    end
  end
end
