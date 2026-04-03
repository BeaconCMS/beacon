defmodule MyApp.Repo.Migrations.ReplaceDeprecatedBeaconAssigns do
  use Ecto.Migration

  import Ecto.Query

  @moduledoc """
  Replaces deprecated Beacon assigns across all content tables and
  republishes page snapshots so the changes take effect immediately.

    - @beacon_live_data.key → @key
    - @beacon_live_data["key"] → @key
    - @beacon_path_params → @beacon.path_params
    - @beacon_query_params → @beacon.query_params
  """

  # All tables and columns that may contain template/code references
  @targets [
    {"beacon_pages", "template"},
    {"beacon_layouts", "template"},
    {"beacon_error_pages", "template"},
    {"beacon_components", "template"},
    {"beacon_components", "body"},
    {"beacon_snippet_helpers", "body"},
    {"beacon_event_handlers", "code"},
    {"beacon_info_handlers", "code"},
    {"beacon_live_data_assigns", "value"},
  ]

  def up do
    # Phase 1: Update all draft/source content tables via SQL
    for {table, column} <- @targets do
      # @beacon_live_data.key → @key (dot access)
      execute """
      UPDATE #{table}
      SET #{column} = regexp_replace(#{column}, '@beacon_live_data\\.([a-zA-Z_][a-zA-Z0-9_]*)', '@\\1', 'g')
      WHERE #{column} LIKE '%@beacon_live_data.%'
      """

      # @beacon_live_data["key"] → @key (bracket string access)
      execute """
      UPDATE #{table}
      SET #{column} = regexp_replace(#{column}, '@beacon_live_data\\["([a-zA-Z_][a-zA-Z0-9_]*)"\\]', '@\\1', 'g')
      WHERE #{column} LIKE '%@beacon_live_data[%'
      """

      # @beacon_path_params → @beacon.path_params
      execute """
      UPDATE #{table}
      SET #{column} = replace(#{column}, '@beacon_path_params', '@beacon.path_params')
      WHERE #{column} LIKE '%@beacon_path_params%'
      """

      # @beacon_query_params → @beacon.query_params
      execute """
      UPDATE #{table}
      SET #{column} = replace(#{column}, '@beacon_query_params', '@beacon.query_params')
      WHERE #{column} LIKE '%@beacon_query_params%'
      """
    end

    # Phase 2: Update published page snapshots
    # Snapshots store serialized %Page{} structs — we need to deserialize,
    # fix the template, and re-serialize each one.
    flush()
    update_page_snapshots()

    # Phase 3: Update published layout snapshots
    update_layout_snapshots()
  end

  defp update_page_snapshots do
    snapshots =
      from(s in "beacon_page_snapshots", select: %{id: s.id, page: s.page})
      |> repo().all()

    for %{id: id, page: page_binary} <- snapshots do
      page = :erlang.binary_to_term(page_binary)
      updated_page = fix_page_assigns(page)

      if updated_page != page do
        new_binary = :erlang.term_to_binary(updated_page)

        from(s in "beacon_page_snapshots", where: s.id == ^id)
        |> repo().update_all(set: [page: new_binary])
      end
    end
  end

  defp update_layout_snapshots do
    snapshots =
      from(s in "beacon_layout_snapshots", select: %{id: s.id, layout: s.layout})
      |> repo().all()

    for %{id: id, layout: layout_binary} <- snapshots do
      layout = :erlang.binary_to_term(layout_binary)
      updated_layout = fix_template_field(layout)

      if updated_layout != layout do
        new_binary = :erlang.term_to_binary(updated_layout)

        from(s in "beacon_layout_snapshots", where: s.id == ^id)
        |> repo().update_all(set: [layout: new_binary])
      end
    end
  end

  defp fix_page_assigns(page) do
    page
    |> fix_template_field()
    |> fix_variants()
  end

  defp fix_template_field(%{template: template} = record) when is_binary(template) do
    %{record | template: replace_deprecated(template)}
  end

  defp fix_template_field(record), do: record

  defp fix_variants(%{variants: variants} = page) when is_list(variants) do
    updated = Enum.map(variants, fn variant ->
      case variant do
        %{template: t} when is_binary(t) -> %{variant | template: replace_deprecated(t)}
        _ -> variant
      end
    end)

    %{page | variants: updated}
  end

  defp fix_variants(page), do: page

  defp replace_deprecated(text) when is_binary(text) do
    text
    |> String.replace(~r/@beacon_live_data\.([a-zA-Z_][a-zA-Z0-9_]*)/, "@\\1")
    |> String.replace(~r/@beacon_live_data\["([a-zA-Z_][a-zA-Z0-9_]*)"\]/, "@\\1")
    |> String.replace("@beacon_path_params", "@beacon.path_params")
    |> String.replace("@beacon_query_params", "@beacon.query_params")
  end

  defp replace_deprecated(text), do: text

  def down do
    for {table, column} <- @targets do
      execute """
      UPDATE #{table}
      SET #{column} = regexp_replace(#{column}, '@beacon\\.path_params', '@beacon_path_params', 'g')
      WHERE #{column} LIKE '%@beacon.path_params%'
      """

      execute """
      UPDATE #{table}
      SET #{column} = regexp_replace(#{column}, '@beacon\\.query_params', '@beacon_query_params', 'g')
      WHERE #{column} LIKE '%@beacon.query_params%'
      """
    end

    raise "Cannot automatically reverse @beacon_live_data replacements — manual review required"
  end
end
