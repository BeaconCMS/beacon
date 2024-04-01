defmodule Beacon.Repo.Migrations.EmbedPageEvents do
  use Ecto.Migration

  defp page_ids do
    query = """
    SELECT DISTINCT page_id FROM beacon_page_events
    """

    case repo().query(query, [], log: :info) do
      {:ok, result} ->
        for row <- result.rows do
          %{page_id: page_id} = repo().load(%{page_id: :binary_id}, {result.columns, row})
          {:ok, page_id} = Ecto.UUID.dump(page_id)
          page_id
        end

      _ ->
        []
    end
  end

  defp events_for_page(page_id) do
    query = """
    SELECT id, code, event_name FROM beacon_page_events WHERE page_id = $1
    """

    case repo().query(query, [page_id], log: :info) do
      {:ok, result} ->
        types = %{id: :binary_id, code: :string, event_name: :string}

        Enum.map(result.rows, fn row ->
          %{id: id, code: code, event_name: event_name} =
            repo().load(types, {result.columns, row})

          %{id: id, code: code, name: event_name}
        end)

      _ ->
        []
    end
  end

  defp update_page_events(events, page_id) do
    execute(fn ->
      repo().query!(
        """
        UPDATE beacon_pages
           SET events = $1
         WHERE id = $2
        """,
        [events, page_id],
        log: :info
      )
    end)
  end

  def up do
    alter table("beacon_pages") do
      add :events, :map, comment: "liveview events consumed by handle_event"
    end

    for page_id <- page_ids() do
      page_id
      |> events_for_page()
      |> update_page_events(page_id)
    end

    drop table("beacon_page_events")
  end

  def down do
    alter table("beacon_pages") do
      remove :events
    end
  end
end
