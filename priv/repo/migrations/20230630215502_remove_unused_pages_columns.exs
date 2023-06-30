defmodule Beacon.Repo.Migrations.RemoveUnusedPagesColumns do
  use Ecto.Migration

  def up do
    alter table("beacon_pages") do
      remove_if_exists :pending_layout_id, :binary_id
      remove_if_exists :pending_template, :text
      remove_if_exists :version, :integer
      remove_if_exists :status, :string
    end
  end

  def down do
  end
end
