defmodule Beacon.Repo.Migrations.AddResourceLinksToLayouts do
  use Ecto.Migration

  def up do
    alter table(:beacon_layouts) do
      add :resource_links, :map, default: %{}, null: false
    end

    for layout_id <- layout_ids() do
      layout_id
      |> stylesheet_links_for_layout()
      |> update_layout_links(layout_id)
    end

    alter table(:beacon_layouts) do
      remove :stylesheet_urls
    end
  end

  defp layout_ids do
    query = """
    SELECT DISTINCT id FROM beacon_layouts
    """

    case repo().query(query, [], log: :info) do
      {:ok, result} ->
        for row <- result.rows do
          %{id: id} = repo().load(%{id: :binary_id}, {result.columns, row})
          Ecto.UUID.dump!(id)
        end

      _ ->
        []
    end
  end

  defp stylesheet_links_for_layout(layout_id) do
    query = """
    SELECT stylesheet_urls FROM beacon_layouts WHERE id = $1
    """

    case repo().query(query, [layout_id], log: :info) do
      {:ok, result} ->
        types = %{stylesheet_urls: {:array, :string}}

        for row <- result.rows,
            %{stylesheet_urls: stylesheet_urls} = repo().load(types, {result.columns, row}),
            href <- stylesheet_urls do
          %{
            href: href,
            ref: "stylesheet"
          }
        end

      _ ->
        []
    end
  end

  defp update_layout_links(links, layout_id) do
    execute(fn ->
      repo().query!(
        """
        UPDATE beacon_layouts
           SET resource_links = $1
         WHERE id = $2
        """,
        [links, layout_id],
        log: :info
      )
    end)
  end

  def down do
    alter table(:beacon_layouts) do
      remove :resource_links
    end
  end
end
