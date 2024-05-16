defmodule Beacon.Repo.Migrations.EmbedPageHelpers do
  use Ecto.Migration

  defp page_ids do
    query = """
    SELECT DISTINCT page_id FROM beacon_page_helpers
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

  defp helpers_for_page(page_id) do
    query = """
    SELECT id, code, helper_name FROM beacon_page_helpers WHERE page_id = $1
    """

    case repo().query(query, [page_id], log: :info) do
      {:ok, result} ->
        types = %{id: :binary_id, code: :string, helper_name: :string}

        Enum.map(result.rows, fn row ->
          %{id: id, code: code, helper_name: helper_name} =
            repo().load(types, {result.columns, row})

          %{id: id, code: code, name: helper_name}
        end)

      _ ->
        []
    end
  end

  defp update_page_helpers(page_id, helpers) do
    execute(fn ->
      repo().query!(
        """
        UPDATE beacon_pages
           SET helpers = $1
         WHERE id = $2
        """,
        [helpers, page_id],
        log: :info
      )
    end)
  end

  def up do
    alter table("beacon_pages") do
      add :helpers, :map
    end

    for page_id <- page_ids() do
      helpers = helpers_for_page(page_id)
      update_page_helpers(page_id, helpers)
    end

    drop table("beacon_page_helpers")
  end

  def down do
    alter table("beacon_pages") do
      remove :helpers
    end
  end
end
