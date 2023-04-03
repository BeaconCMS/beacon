defmodule Beacon.Repo.Migrations.AddStatusToPages do
  use Ecto.Migration

  def up do
    alter table(:beacon_pages) do
      add :status, :string
    end

    execute """
    UPDATE beacon_pages SET status = 'published'
    """
  end

  def down do
    alter table(:beacon_pages) do
      remove :status
    end
  end
end
