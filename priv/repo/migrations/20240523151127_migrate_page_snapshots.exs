defmodule Beacon.Repo.Migrations.MigratePageSnapshots do
  use Ecto.Migration

  def up do
    alter table(:beacon_page_snapshots) do
      add_if_not_exists :path, :text
      add_if_not_exists :title, :text
      add_if_not_exists :format, :text
      add_if_not_exists :extra, :map
    end

    for %{id: id, page: page} <- snapshots() do
      update_snapshot(id, page)
    end
  end

  defp snapshots do
    query = """
    SELECT id, page FROM beacon_page_snapshots
    """

    schema = %{
      id: :binary_id,
      page: Beacon.Types.Binary
    }

    case repo().query(query, []) do
      {:ok, result} ->
        Enum.map(result.rows, fn row ->
          snapshot = repo().load(schema, {result.columns, row})
          page = extract_page_snapshot(snapshot)
          %{snapshot | page: page}
        end)

      _ ->
        []
    end
  end

  defp update_snapshot(id, page) do
    id = Ecto.UUID.dump!(id)
    format = Atom.to_string(page.format)

    execute(fn ->
      repo().query!(
        """
        UPDATE beacon_page_snapshots
           SET path = $2,
               title = $3,
               format = $4,
               extra = $5
         WHERE id = $1
        """,
        [
          id,
          page.path,
          page.title,
          format,
          page.extra
        ],
        log: :info
      )
    end)
  end

  defp extract_page_snapshot(%{page: page}) do
    page
    |> repo().reload()
    |> maybe_add_leading_slash()
  end

  defp maybe_add_leading_slash(%{path: <<"/", _rest::binary>>} = page), do: page

  defp maybe_add_leading_slash(page) do
    path = "/" <> page.path
    %{page | path: path}
  end

  def down do
  end
end
