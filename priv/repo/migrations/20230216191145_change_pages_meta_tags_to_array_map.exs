defmodule Beacon.Repo.Migrations.ChangePagesMetaTagsToArrayMap do
  use Ecto.Migration

  def up do
    # temporary column to hold transformed meta tags
    alter table(:beacon_pages) do
      add :array_meta_tags, {:array, :map}
    end

    query_page_meta_tags = """
      SELECT id, meta_tags AS old_meta_tags FROM beacon_pages
    """

    types = %{id: :binary_id, old_meta_tags: :map}

    case repo().query(query_page_meta_tags) do
      {:ok, result} ->
        # for each row, query old meta tags, transform it, and store the transformed values as array
        for row <- result.rows do
          %{id: id, old_meta_tags: old_meta_tags} = repo().load(types, {result.columns, row})
          {:ok, id} = Ecto.UUID.dump(id)

          new_meta_tags =
            Enum.map(old_meta_tags, fn {key, value} ->
              %{"name" => key, "content" => value}
            end)

          execute(fn ->
            repo().query!(
              """
              UPDATE beacon_pages
                 SET array_meta_tags = $1
               WHERE id = $2
              """,
              [new_meta_tags, id],
              log: :info
            )
          end)
        end

      _ ->
        :skip
    end

    # remove old meta tags
    alter table(:beacon_pages) do
      remove :meta_tags
    end

    # make the new column the current meta tags value
    rename table(:beacon_pages), :array_meta_tags, to: :meta_tags
  end

  # do nothing
  def down do
  end
end
