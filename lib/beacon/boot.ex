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

  def init(%{site: site, mode: :manual}) do
    Logger.debug("Beacon.Boot is disabled for site #{site} on manual mode")

    # Router helpers are always available
    # TODO: we should be able to remove the next line after implementing `:error_handler` callbacks
    Beacon.Loader.reload_routes_module(site)

    :ignore
  end

  def init(%{site: site, mode: :testing}) do
    Logger.debug("Beacon.Boot is disabled for site #{site} on testing mode")

    # reload shared modules used by layouts and pages
    # Router helpers are always available
    # TODO: we should be able to remove the next lines after implementing `:error_handler` callbacks
    Beacon.Loader.reload_routes_module(site)
    Beacon.Loader.reload_components_module(site)
    Beacon.Loader.reload_live_data_module(site)

    :ignore
  end

  def init(config), do: live_init(config.site)

  # TODO: we should be able to remove most of the Loader calls here, probably keep only runtime js/css
  def live_init(site) do
    Logger.info("Beacon.Boot booting site #{site}")
    task_supervisor = Beacon.Registry.via({site, TaskSupervisor})

    # temporary disable module reloadin so we can populate data more efficiently
    %{mode: :manual} = Beacon.Config.update_value(site, :mode, :manual)
    Beacon.Loader.populate_default_media(site)
    Beacon.Loader.populate_default_components(site)
    Beacon.Loader.populate_default_layouts(site)
    Beacon.Loader.populate_default_error_pages(site)
    Beacon.Loader.populate_default_home_page(site)

    %{mode: :live} = Beacon.Config.update_value(site, :mode, :live)

    # Sigils and router helpers
    Beacon.Loader.reload_routes_module(site)

    # Layouts and pages depend on the components module so we need to load them first
    Beacon.Loader.reload_components_module(site)

    assets = [
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_runtime_js(site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_runtime_css(site) end)
    ]

    modules = [
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_stylesheet_module(site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_snippets_module(site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_live_data_module(site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_layouts_modules(site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_error_page_module(site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_pages_modules(site, per_page: 20) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_info_handlers_module(site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.reload_event_handlers_module(site) end)
      # TODO: load main pages (order_by: path, per_page: 10) to avoid SEO issues
    ]

    Task.await_many(modules, :timer.minutes(10))

    # TODO: revisit this timeout after we upgrade to Tailwind v4
    Task.await_many(assets, :timer.minutes(5))

    # TODO: add telemetry to measure booting time
    Logger.info("Beacon.Boot finished booting site #{site}")

    :ignore
  end
end
