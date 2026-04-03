defmodule MyApp.Repo.Migrations.ReplaceDeprecatedBeaconAssigns do
  use Ecto.Migration

  @doc """
  Replaces deprecated Beacon assigns across all content tables:

    - @beacon_live_data.key → @key
    - @beacon_live_data["key"] → @key
    - @beacon_path_params → @beacon.path_params
    - @beacon_query_params → @beacon.query_params

  After running this migration, republish all pages to update snapshots:

      for site <- [:my_site] do
        Beacon.Content.list_pages(site, per_page: :infinity)
        |> Enum.each(fn page ->
          Beacon.Content.publish_page(page)
        end)
      end
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
  end

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
