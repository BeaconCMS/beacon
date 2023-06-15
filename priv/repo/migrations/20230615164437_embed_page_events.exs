defmodule Beacon.Repo.Migrations.EmbedPageEvents do
  use Ecto.Migration

  def up do
    alter table("beacon_pages") do
      add :events, :map, comment: "liveview events consumed by handle_event"
    end

    query_page_events = """
    SELECT id, page_id, code, event_name FROM beacon_page_events
    """

    types = %{id: :binary_id, page_id: :binary_id, code: :string, event_name: :string}

    case repo().query(query_page_events) do
      {:ok, result} ->
        for row <- result.rows do
          %{id: id, page_id: page_id, code: code, event_name: name} = repo().load(types, {result.columns, row})
          {:ok, page_id} = Ecto.UUID.dump(page_id)

          embedded_event = %{
            id: id,
            code: code,
            name: name
          }

          # TODO: group events
          execute(fn ->
            repo().query!(
              """
              UPDATE beacon_pages
                 SET events = $1
               WHERE id = $2
              """,
              [embedded_event, page_id],
              log: :info
            )
          end)
        end

      _ ->
        :skip
    end

    drop table("beacon_page_events")
  end

  def down do
    alter table("beacon_pages") do
      remove :events
    end
  end
end
