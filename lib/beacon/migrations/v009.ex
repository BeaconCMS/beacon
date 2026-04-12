defmodule Beacon.Migrations.V009 do
  @moduledoc false
  use Ecto.Migration

  def up do
    alter table(:beacon_pages) do
      add_if_not_exists :ast, :map
    end

    alter table(:beacon_page_snapshots) do
      add_if_not_exists :ast, :map
    end

    alter table(:beacon_components) do
      add_if_not_exists :ast, :map
    end

    alter table(:beacon_layouts) do
      add_if_not_exists :ast, :map
    end

    alter table(:beacon_layout_snapshots) do
      add_if_not_exists :ast, :map
    end
  end

  def down do
    alter table(:beacon_layout_snapshots) do
      remove_if_exists :ast, :map
    end

    alter table(:beacon_layouts) do
      remove_if_exists :ast, :map
    end

    alter table(:beacon_components) do
      remove_if_exists :ast, :map
    end

    alter table(:beacon_page_snapshots) do
      remove_if_exists :ast, :map
    end

    alter table(:beacon_pages) do
      remove_if_exists :ast, :map
    end
  end
end
