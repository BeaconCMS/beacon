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

    flush()

    repo().all(
      from(peh in "beacon_page_event_handlers",
        join: p in "beacon_pages",
        on: peh.page_id == p.id,
        select: %{site: p.site, name: peh.name, code: peh.code},
        # distinct saves us memory in cases of duplicate code
        distinct: true
      )
    )
    # we still need to avoid duplicates where the code is different
    |> Enum.group_by(&{&1.site, &1.name}, & &1.code)
    |> Enum.map(fn {{site, name}, [code | _]} ->
      now = DateTime.utc_now()
      %{id: Ecto.UUID.generate() |> Ecto.UUID.dump!(), name: name, code: code, site: site, inserted_at: now, updated_at: now}
    end)
    |> then(&repo().insert_all("beacon_event_handlers", &1, []))

    drop_if_exists table(:beacon_page_event_handlers)

    create_if_not_exists table(:beacon_info_handlers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :site, :text, null: false
      add :msg, :text, null: false
      add :code, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end
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

    drop_if_exists table(:beacon_info_handlers)
  end
end
