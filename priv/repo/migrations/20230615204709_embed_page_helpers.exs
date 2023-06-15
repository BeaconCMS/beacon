defmodule Beacon.Repo.Migrations.EmbedPageHelpers do
  use Ecto.Migration

  def up do
    alter table("beacon_pages") do
      add :helpers, :map
    end

    query_page_helpers = """
    SELECT id, page_id, code, helper_name, helper_args FROM beacon_page_helpers
    """

    types = %{id: :binary_id, page_id: :binary_id, code: :string, helper_name: :string, helper_args: :string}

    case repo().query(query_page_helpers) do
      {:ok, result} ->
        for row <- result.rows do
          %{id: id, page_id: page_id, code: code, helper_name: name, helper_args: args} = repo().load(types, {result.columns, row})
          {:ok, page_id} = Ecto.UUID.dump(page_id)

          embedded_helper = %{
            id: id,
            code: code,
            name: name,
            args: args
          }

          execute(fn ->
            repo().query!(
              """
              UPDATE beacon_pages
                 SET helpers = $1
               WHERE id = $2
              """,
              [embedded_helper, page_id],
              log: :info
            )
          end)
        end

      _ ->
        :skip
    end

    drop table("beacon_page_helpers")
  end

  def down do
    alter table("beacon_pages") do
      remove :helpers
    end
  end
end
