defmodule Beacon.Repo.Migrations.ConvertTimestampsToUtcDatetimeUsec do
  use Ecto.Migration

  defp convert(table) do
    alter table(table) do
      modify :inserted_at, :utc_datetime_usec
      modify :updated_at, :utc_datetime_usec
    end

    query = """
      SELECT id, inserted_at, updated_at FROM #{table}
    """

    types = %{id: :binary_id, inserted_at: :utc_datetime_usec, updated_at: :utc_datetime_usec}

    case repo().query(query) do
      {:ok, result} ->
        for row <- result.rows do
          %{id: id, inserted_at: inserted_at, updated_at: updated_at} =
            repo().load(types, {result.columns, row})

          {:ok, id} = Ecto.UUID.dump(id)

          execute(fn ->
            repo().query!(
              """
              UPDATE #{table}
                 SET inserted_at = $1, updated_at = $2
               WHERE id = $3
              """,
              [inserted_at, updated_at, id],
              log: :info
            )
          end)
        end

      _ ->
        :skip
    end
  end

  def up do
    convert("beacon_pages")
    convert("beacon_layouts")
    convert("beacon_components")
    convert("beacon_page_versions")
    convert("beacon_stylesheets")
    convert("beacon_snippet_helpers")
    convert("beacon_assets")
  end

  def down do
  end
end
