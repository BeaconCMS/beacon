defmodule Beacon.Repo.Migrations.ComponentsEnforceNameAsFunction do
  use Ecto.Migration

  def up do
    for %{id: id, name: name} <- components() do
      name =
        name
        |> String.replace(" ", "_")
        |> String.downcase()
        |> String.replace(~r/[^0-9a-z_]+/, "")

      update_component(id, name)
    end
  end

  defp components do
    query = """
    SELECT id, name FROM beacon_components
    """

    case repo().query(query, [], log: :info) do
      {:ok, result} ->
        Enum.map(result.rows, fn row ->
          repo().load(%{id: :binary_id, name: :string}, {result.columns, row})
        end)

      _ ->
        []
    end
  end

  defp update_component(id, name) do
    id = Ecto.UUID.dump!(id)

    execute(fn ->
      repo().query!(
        """
        UPDATE beacon_components
           SET name = $1
         WHERE id = $2
        """,
        [name, id],
        log: :info
      )
    end)
  end

  def down do
  end
end
