defmodule Beacon.Migrations.V002 do
  @moduledoc false
  use Ecto.Migration

  import Ecto.Query

  def up do
    create_if_not_exists table(:beacon_event_handlers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false
      add :code, :text, null: false
      add :site, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists table("beacon_page_event_handlers", primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false
      add :code, :text, null: false
      add :site, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    repo().all(
      from(peh in "beacon_page_event_handlers",
        join: p in "beacon_pages",
        on: peh.page_id == p.id,
        group_by: [peh.page_id, p.site],
        select: {max(peh.id), peh.name, max(peh.code), p.site}
      )
    )
    |> Enum.map(fn {id, name, code, site} ->
      now = DateTime.utc_now()
      %{id: id, name: name, code: code, site: site, inserted_at: now, updated_at: now}
    end)
    |> then(&repo().insert_all("beacon_event_handlers", &1, []))

    # execute("""
    # INSERT INTO beacon_event_handlers (id, name, code, site)
    #   SELECT max(peh.id::text)::uuid, peh.name, max(peh.code), p.site
    #     FROM beacon_page_event_handlers as peh
    #     JOIN beacon_pages as p
    #     ON peh.page_id = p.id
    #     GROUP BY peh.name, p.site;
    # """)

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
