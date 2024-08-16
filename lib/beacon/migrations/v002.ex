defmodule Beacon.Migrations.V002 do
  @moduledoc false
  use Ecto.Migration

  def up do
    create_if_not_exists table(:beacon_event_handlers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false
      add :code, :text, null: false
      add :site, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    execute("""
    INSERT INTO beacon_event_handlers (id, name, code, site)
      SELECT max(peh.id::text), peh.name, max(peh.code), p.site
        FROM beacon_page_event_handlers as peh
        JOIN beacon_pages as p
        ON peh.page_id = p.id
        GROUP BY peh.name, p.site;
    """)

    drop_if_exists table(:beacon_page_event_handlers)
  end

  def down do
    create_if_not_exists table(:beacon_page_event_handlers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false
      add :code, :text, null: false

      add :page_id, references(:beacon_pages, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime_usec)
    end

    # global event handlers can't be converted back into page event handlers

    drop_if_exists table(:beacon_event_handlers)
  end
end
