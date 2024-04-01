defmodule Beacon.Repo.Migrations.MigratePagesEventsSnapshots do
  use Ecto.Migration
  import Ecto.Query
  alias Beacon.Content
  alias Beacon.Repo

  def up do
    load_atoms()

    for page <- fetch_all_pages() do
      {:ok, event} = Content.create_page_event(page, "created")
      update_inserted_at(event, page.inserted_at)

      {:ok, event} = Content.create_page_event(page, "published")
      update_inserted_at(event, page.updated_at)

      {:ok, snapshot} = Content.create_page_snapshot(page, event)
      update_inserted_at(snapshot, page.updated_at)
    end
  end

  def down do
    query = """
    TRUNCATE beacon_page_events;
    TRUNCATE beacon_page_snapshots;
    """

    repo().query(query, [])
  end

  defp load_atoms do
    query = """
    SELECT DISTINCT site, format FROM beacon_pages
    """

    case repo().query(query, [], log: :info) do
      {:ok, result} ->
        Enum.map(result.rows, fn row ->
          %{site: site, format: format} =
            repo().load(%{site: :string, format: :string}, {result.columns, row})

          _ = String.to_atom(site)
          _ = String.to_atom(format)
        end)

      _ ->
        []
    end
  end

  defp fetch_all_pages do
    query = """
    SELECT * FROM beacon_pages;
    """

    schema = %{
      site: :string,
      path: :string,
      title: :string,
      description: :string,
      template: :string,
      meta_tags: :map,
      raw_schema: :map,
      order: :integer,
      format: :atom,
      extra: :map,
      layout_id: :string,
      events: :array,
      helpers: :array,
      inserted_at: :datetime_usec,
      updated_at: :datetime_usec
    }

    case repo().query(query, []) do
      {:ok, result} -> Enum.map(result.rows, &repo().load(schema, {result.columns, &1}))
      _ -> []
    end
  end

  defp update_inserted_at(%schema{id: id}, inserted_at) do
    query = from(s in schema, where: s.id == ^id)
    Repo.update_all(query, set: [inserted_at: inserted_at])
  end
end
