defmodule Beacon.Repo.Migrations.MigrateBeaconPagesMetaTagsInterpolation do
  use Ecto.Migration

  def up do
    query_page_meta_tags = """
    SELECT id, meta_tags FROM beacon_pages
    """

    types = %{id: :binary_id, meta_tags: {:array, :map}}

    case repo().query(query_page_meta_tags) do
      {:ok, result} ->
        for row <- result.rows do
          %{id: id, meta_tags: meta_tags} = repo().load(types, {result.columns, row})
          {:ok, id} = Ecto.UUID.dump(id)

          update_meta_tag = fn meta_tag ->
            Map.new(meta_tag, fn {k, v} ->
              v =
                v
                |> String.replace("%path%", "{{ page.path }}")
                |> String.replace("%title%", "{{ page.title }}")
                |> String.replace("%description%", "{{ page.description }}")

              {k, v}
            end)
          end

          new_meta_tags = Enum.map(meta_tags, fn meta_tag -> update_meta_tag.(meta_tag) end)

          execute(fn ->
            repo().query!(
              """
              UPDATE beacon_pages
                 SET meta_tags = $1
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
  end

  def down do
  end
end
