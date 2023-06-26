defmodule Beacon.Repo.Migrations.MigratePagesEventsSnapshots do
  use Ecto.Migration
  import Ecto.Query
  alias Beacon.Content
  alias Beacon.Repo

  defp load_atoms do
    query = """
    SELECT DISTINCT site, format FROM beacon_pages
    """

    case repo().query(query, [], log: :info) do
      {:ok, result} ->
        Enum.map(result.rows, fn row ->
          %{site: site, format: format} = repo().load(%{site: :string, format: :string}, {result.columns, row})
          String.to_atom(site)
          String.to_atom(format)
        end)

      _ ->
        []
    end
  end

  defp update_inserted_at(%schema{id: id}, inserted_at) do
    query = from s in schema, where: s.id == ^id
    Repo.update_all(query, set: [inserted_at: inserted_at])
  end

  def up do
    load_atoms()

    for page <- Repo.all(Content.Page) do
      {:ok, event} = Content.create_page_event(page, "created")
      update_inserted_at(event, page.inserted_at)

      {:ok, event} = Content.create_page_event(page, "published")
      update_inserted_at(event, page.updated_at)

      {:ok, snapshot} = Content.create_page_snapshot(page, event)
      update_inserted_at(snapshot, page.updated_at)
    end
  end

  def down do
    Repo.delete_all(Content.PageEvent)
    Repo.delete_all(Content.PageSnapshot)
  end
end
