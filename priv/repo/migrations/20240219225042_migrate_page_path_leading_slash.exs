defmodule Beacon.Repo.Migrations.MigratePagePathLeadingSlash do
  use Ecto.Migration

  # migrate draft pages
  # handle published pages in Content when it gets extracted

  def up do
    for %{id: id, path: path} <- pages(), !is_nil(path) && !String.starts_with?(path, "/") do
      path = "/" <> path
      update_page(id, path)
    end
  end

  defp pages do
    query = """
    SELECT id, path FROM beacon_pages;
    """

    case repo().query(query, [], log: :info) do
      {:ok, result} ->
        Enum.map(result.rows, fn row ->
          repo().load(%{id: :binary_id, path: :string}, {result.columns, row})
        end)

      _ ->
        []
    end
  end

  defp update_page(id, path) do
    id = Ecto.UUID.dump!(id)

    execute(fn ->
      repo().query!(
        """
        UPDATE beacon_pages
           SET path = $1
         WHERE id = $2
        """,
        [path, id],
        log: :info
      )
    end)
  end

  def down do
  end
end
