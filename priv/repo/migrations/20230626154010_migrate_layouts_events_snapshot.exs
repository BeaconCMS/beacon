defmodule Beacon.Repo.Migrations.MigrateLayoutsEventsSnapshots do
  use Ecto.Migration
  import Ecto.Query
  alias Beacon.Content
  alias Beacon.Repo

  defp load_atoms do
    query = """
    SELECT DISTINCT site FROM beacon_layouts
    """

    case repo().query(query, [], log: :info) do
      {:ok, result} ->
        Enum.map(result.rows, fn row ->
          %{site: site} = repo().load(%{site: :string}, {result.columns, row})
          String.to_atom(site)
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

    for layout <- Repo.all(Content.Layout) do
      {:ok, event} = Content.create_layout_event(layout, "created")
      update_inserted_at(event, layout.inserted_at)

      {:ok, event} = Content.create_layout_event(layout, "published")
      update_inserted_at(event, layout.inserted_at)

      {:ok, snapshot} = Content.create_layout_snapshot(layout, event)
      update_inserted_at(snapshot, layout.inserted_at)
    end
  end

  def down do
    Repo.delete_all(Content.LayoutEvent)
    Repo.delete_all(Content.LayoutSnapshot)
  end
end
