defmodule Beacon.Repo.Migrations.MigrateEventHandlers do
  use Ecto.Migration

  alias Beacon.Content.Page
  alias Beacon.Content.PageEventHandler
  alias Beacon.Repo

  def up do
    Enum.each(pages_events(), fn %{id: page_id, events: events} ->
      Enum.each(events, fn %{"code" => code, "name" => name} ->
        %Page{id: page_id}
        |> Ecto.build_assoc(:event_handlers)
        |> PageEventHandler.changeset(%{name: name, code: code})
        |> Repo.insert!()
      end)
    end)
  end

  defp pages_events do
    query = """
    SELECT id, events FROM beacon_pages;
    """

    case repo().query(query, [], log: :info) do
      {:ok, result} ->
        result.rows
        |> Enum.map(fn row ->
          repo().load(%{id: :binary_id, events: {:array, :map}}, {result.columns, row})
        end)
        |> Enum.reject(fn %{events: events} -> is_nil(events) end)

      _ ->
        []
    end
  end

  def down do
  end
end
