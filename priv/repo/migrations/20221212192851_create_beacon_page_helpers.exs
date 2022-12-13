defmodule Beacon.Repo.Migrations.CreateBeaconPageHelpers do
  use Ecto.Migration

  def change do
    create table(:beacon_page_helpers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :text, null: false
      add :order, :integer, null: false
      add :helper_name, :text, null: false
      add :helper_args, :text, null: false
      add :page_id, references(:beacon_pages, on_delete: :nothing, type: :binary_id)

      timestamps()
    end

    create index(:beacon_page_helpers, [:page_id])
  end
end
