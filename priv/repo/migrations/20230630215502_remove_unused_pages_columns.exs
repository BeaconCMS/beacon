defmodule Beacon.Repo.Migrations.RemoveUnusedPagesColumns do
  use Ecto.Migration

  def up do
    alter table("beacon_pages") do
      remove :pending_layout_id
      remove :pending_template
      remove :version
    end
  end

  def down do
  end
end
