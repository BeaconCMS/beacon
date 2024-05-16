defmodule Beacon.Repo.Migrations.MigrateLayoutsEventsSnapshots do
  use Ecto.Migration
  import Ecto.Query
  alias Beacon.Content
  alias Beacon.Repo

  def up do
    load_atoms()

    for layout <- fetch_all_layouts() do
      {:ok, event} = Content.create_layout_event(layout, "created")
      update_inserted_at(event, layout.inserted_at)

      {:ok, event} = Content.create_layout_event(layout, "published")
      update_inserted_at(event, layout.updated_at)

      {:ok, snapshot} = Content.create_layout_snapshot(layout, event)
      update_inserted_at(snapshot, layout.updated_at)
    end
  end

  def down do
    query = """
    TRUNCATE beacon_layout_events;
    TRUNCATE beacon_layout_snapshots;
    """

    repo().query(query, [])
  end

  defp load_atoms do
    query = """
    SELECT DISTINCT site FROM beacon_layouts
    """

    case repo().query(query, [], log: :info) do
      {:ok, result} ->
        Enum.map(result.rows, fn row ->
          %{site: site} = repo().load(%{site: :string}, {result.columns, row})
          _ = String.to_atom(site)
        end)

      _ ->
        []
    end
  end

  defp fetch_all_layouts do
    query = """
    SELECT * FROM beacon_layouts
    """

    schema = %{
      site: :string,
      title: :string,
      body: :string,
      meta_tags: :map,
      stylesheet_urls: :array,
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
