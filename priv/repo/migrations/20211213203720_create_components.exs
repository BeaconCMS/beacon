defmodule Beacon.Repo.Migrations.CreateComponents do
  use Ecto.Migration

  def change do
    create table(:components, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text
      add :name, :text
      add :body, :text

      timestamps()
    end
  end
end
