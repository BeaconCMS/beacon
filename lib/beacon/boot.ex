defmodule Beacon.Boot do
  @moduledoc false

  # Initialized all the required data and components for site
  # so it doesn't crash on initial requests nor display unstyled pages or error pages.

  use GenServer, restart: :transient
  require Logger

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  def init(%{site: site, mode: mode}) when is_atom(site) and mode in [:manual, :testing] do
    Logger.debug("Beacon.Boot is disabled for site #{site} on #{mode} mode")
    :ignore
  end

  def init(%{site: site, mode: :live} = config) when is_atom(site) do
    Logger.info("Beacon.Boot booting site #{site}")
    task_supervisor = Beacon.Registry.via({site, TaskSupervisor})

    # temporary disable module loading so we can populate data more efficiently
    %{mode: :manual} = Beacon.Config.update_value(site, :mode, :manual)
    Beacon.Loader.populate_default_media(site)
    Beacon.Loader.populate_default_components(site)
    Beacon.Loader.populate_default_layouts(site)
    Beacon.Loader.populate_default_error_pages(site)
    Beacon.Loader.populate_default_home_page(site)

    %{mode: :live} = Beacon.Config.update_value(site, :mode, :live)

    tasks = [
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.load_runtime_js(site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.load_runtime_css(site) end)
      | warm_pages_async(task_supervisor, config)
    ]

    # TODO: revisit this timeout after we upgrade to Tailwind v4
    Task.await_many(tasks, :timer.minutes(5))

    # TODO: add telemetry to measure booting time
    Logger.info("Beacon.Boot finished booting site #{site}")

    :ignore
  end

  defp warm_pages_async(task_supervisor, config) do
    pages =
      case config.page_warming do
        {:shortest_paths, count} ->
          Logger.info("Beacon.Boot warming pages - #{count} shortest paths")
          Beacon.Content.list_published_pages(config.site, sort: {:length, :path}, limit: count)

        {:specify_paths, paths} ->
          Logger.info("Beacon.Boot warming pages - specified paths")
          Beacon.Content.list_published_pages_for_paths(config.site, paths)

        :none ->
          Logger.info("Beacon.Boot page warming disabled")
          []
      end

    Enum.map(pages, fn page ->
      Logger.info("Beacon.Boot warming page #{page.id} #{page.path}")
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.load_page_module(config.site, page.id) end)
    end)
  end
end
