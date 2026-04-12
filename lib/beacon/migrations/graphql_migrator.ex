defmodule Beacon.Migrations.GraphQLMigrator do
  @moduledoc """
  Migration tooling for converting existing pages to use GraphQL endpoints.

  Analyzes page configurations and provides guidance for migration.

  ## Usage

      # Preview what would need to change
      Beacon.Migrations.GraphQLMigrator.dry_run(:my_site)
  """

  require Logger

  @doc """
  Analyze a site and report what pages have data source configurations
  in their extra field that should be migrated to page queries.
  """
  @spec analyze(atom()) :: map()
  def analyze(site) do
    config = Beacon.Config.fetch!(site)
    repo = config.repo

    %{rows: page_rows} = repo.query!(
      "SELECT id, path, extra FROM beacon_pages WHERE site = $1",
      [to_string(site)]
    )

    pages_with_data_sources =
      page_rows
      |> Enum.filter(fn [_id, _path, extra] ->
        extra = extra || %{}
        ds = Map.get(extra, "data_sources", [])
        is_list(ds) and ds != []
      end)
      |> Enum.map(fn [id, path, extra] ->
        %{id: id, path: path, data_sources: Map.get(extra || %{}, "data_sources", [])}
      end)

    %{rows: handler_rows} = repo.query!(
      "SELECT id, name, format FROM beacon_event_handlers WHERE site = $1",
      [to_string(site)]
    )

    elixir_handlers =
      handler_rows
      |> Enum.filter(fn [_id, _name, format] -> format == "elixir" or is_nil(format) end)
      |> Enum.map(fn [id, name, _format] -> %{id: id, name: name} end)

    %{
      site: site,
      pages_with_legacy_data_sources: length(pages_with_data_sources),
      pages: pages_with_data_sources,
      elixir_event_handlers: length(elixir_handlers),
      handlers: elixir_handlers
    }
  end

  @doc """
  Preview the migration without making changes.
  Returns a list of steps the developer needs to take.
  """
  @spec dry_run(atom()) :: [binary()]
  def dry_run(site) do
    report = analyze(site)
    steps = []

    steps =
      if report.pages_with_legacy_data_sources > 0 do
        page_steps =
          Enum.flat_map(report.pages, fn page ->
            sources = Enum.map(page.data_sources, fn ds ->
              source = ds["source"] || ds[:source]
              "  - Data source '#{source}' on page #{page.path}"
            end)

            ["Pages with legacy data_sources in extra field (#{page.path}):"] ++ sources
          end)

        steps ++ [
          "== Legacy Data Sources ==",
          "#{report.pages_with_legacy_data_sources} page(s) have data_sources in their extra field.",
          "Steps:",
          "  1. Create a GraphQL endpoint in Beacon admin pointing to your host app's API",
          "  2. For each data source, create a page query with the equivalent GraphQL query",
          "  3. Remove the data_sources from page extra fields",
          "" | page_steps
        ]
      else
        steps ++ ["No legacy data sources found."]
      end

    steps =
      if report.elixir_event_handlers > 0 do
        handler_names = Enum.map(report.handlers, & &1.name) |> Enum.join(", ")

        steps ++ [
          "",
          "== Elixir Event Handlers ==",
          "#{report.elixir_event_handlers} handler(s) use raw Elixir code: #{handler_names}",
          "These can optionally be converted to declarative actions format."
        ]
      else
        steps
      end

    steps
  end

  @doc """
  Clean up legacy data_sources from page extra fields.
  """
  @spec clean_legacy_extra!(atom()) :: :ok
  def clean_legacy_extra!(site) do
    config = Beacon.Config.fetch!(site)
    repo = config.repo

    %{num_rows: count} = repo.query!(
      "UPDATE beacon_pages SET extra = extra - 'data_sources' WHERE site = $1 AND extra ? 'data_sources'",
      [to_string(site)]
    )

    Logger.info("[GraphQLMigrator] Cleaned data_sources from #{count} pages on site #{site}")
    :ok
  end
end
