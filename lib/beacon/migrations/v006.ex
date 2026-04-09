defmodule Beacon.Migrations.V006 do
  @moduledoc false
  use Ecto.Migration
  import Ecto.Query

  def up do
    alter table(:beacon_page_snapshots) do
      add_if_not_exists :template, :text
    end

    flush()

    # Backfill: extract template from the serialized page binary
    repo().all(
      from(s in "beacon_page_snapshots",
        select: %{id: s.id, page: s.page},
        where: is_nil(s.template)
      )
    )
    |> Enum.each(fn %{id: id, page: page_binary} ->
      case safe_extract_template(page_binary) do
        {:ok, template} ->
          repo().update_all(
            from(s in "beacon_page_snapshots", where: s.id == ^id),
            set: [template: template]
          )

        :error ->
          :ok
      end
    end)
  end

  def down do
    alter table(:beacon_page_snapshots) do
      remove_if_exists :template, :text
    end
  end

  defp safe_extract_template(nil), do: :error

  defp safe_extract_template(binary) when is_binary(binary) do
    try do
      case :erlang.binary_to_term(binary) do
        %{template: t} when is_binary(t) -> {:ok, t}
        _ -> :error
      end
    rescue
      _ -> :error
    end
  end
end
