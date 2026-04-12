defmodule Beacon.Migrations.GraphQLMigrator do
  @moduledoc """
  Migration tooling for converting existing pages to use GraphQL endpoints.

  Analyzes page configurations and provides guidance for migration.

  ## Usage

      # Preview what would need to change
      Beacon.Migrations.GraphQLMigrator.dry_run(:my_site)
  """

  import Ecto.Query
  require Logger

  @doc """
  Analyze a site and report what pages have data source configurations
  in their extra field that should be migrated to page queries.
  """
  @spec analyze(atom()) :: map()
  def analyze(site) do
    config = Beacon.Config.fetch!(site)
    repo = config.repo

    # Find pages with data_sources in their extra field
    pages_with_data_sources =
      repo.all(
        Ecto.Query.from(p in "beacon_pages",
          where: p.site == ^to_string(site),
          select: %{id: p.id, path: p.path, extra: p.extra}
        )
      )
      |> Enum.filter(fn page ->
        extra = page.extra || %{}
        ds = Map.get(extra, "data_sources", [])
        is_list(ds) and ds != []
      end)

    # Find event handlers using elixir format (candidates for conversion)
    elixir_handlers =
      repo.all(
        Ecto.Query.from(eh in "beacon_event_handlers",
          where: eh.site == ^to_string(site),
          select: %{id: eh.id, name: eh.name, format: eh.format}
        )
      )
      |> Enum.filter(fn h -> h.format == "elixir" or is_nil(h.format) end)

    %{
      site: site,
      pages_with_legacy_data_sources: length(pages_with_data_sources),
      pages: Enum.map(pages_with_data_sources, fn p ->
        %{
          id: p.id,
          path: p.path,
          data_sources: Map.get(p.extra || %{}, "data_sources", [])
        }
      end),
      elixir_event_handlers: length(elixir_handlers),
      handlers: Enum.map(elixir_handlers, &%{id: &1.id, name: &1.name})
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
          "These were configured via the old DataStore system and need to be converted to page queries.",
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
          "These can optionally be converted to declarative actions format.",
          "Use the Event Handler editor's format toggle to switch between Elixir and Actions."
        ]
      else
        steps
      end

    steps
  end

  @doc """
  Clean up legacy data_sources from page extra fields.
  This removes the data_sources key from the extra map of all pages on the site.
  """
  @spec clean_legacy_extra!(atom()) :: :ok
  def clean_legacy_extra!(site) do
    config = Beacon.Config.fetch!(site)
    repo = config.repo

    {count, _} =
      repo.update_all(
        Ecto.Query.from(p in "beacon_pages",
          where: p.site == ^to_string(site)
        ),
        set: [extra: Ecto.Query.dynamic([p], fragment("? - 'data_sources'", p.extra))]
      )

    Logger.info("[GraphQLMigrator] Cleaned data_sources from #{count} pages on site #{site}")
    :ok
  end
end
