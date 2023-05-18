defmodule Beacon.Repo.Migrations.CreateBeaconSnippetHelpers do
  use Ecto.Migration

  def change do
    create table(:beacon_snippet_helpers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :body, :text, null: false
      add :name, :text, null: false

      timestamps()
    end

    create unique_index(:beacon_snippet_helpers, [:site, :name])
  end
end
