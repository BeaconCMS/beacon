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

  def init(%{site: site, mode: :manual}) when is_atom(site) do
    Logger.debug("Beacon.Boot is disabled for site #{site} on manual mode")
    :ignore
  end

  def init(%{site: site, mode: :testing}) when is_atom(site) do
    Logger.debug("Beacon.Boot is disabled for site #{site} on testing mode")

    # load modules that are expected to be available, even empty
    # Beacon.Loader.load_routes_module(site)
    # Beacon.Loader.load_components_module(site)
    Beacon.Loader.load_live_data_module(site)

    :ignore
  end

  def init(%{site: site, mode: :live}) when is_atom(site) do
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

    # still needed to test Beacon itself
    # Beacon.Loader.load_routes_module(site)
    # Beacon.Loader.load_components_module(site)

    assets = [
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.load_runtime_js(site) end),
      Task.Supervisor.async(task_supervisor, fn -> Beacon.Loader.load_runtime_css(site) end)
    ]

    # TODO: revisit this timeout after we upgrade to Tailwind v4
    Task.await_many(assets, :timer.minutes(5))

    # TODO: add telemetry to measure booting time
    Logger.info("Beacon.Boot finished booting site #{site}")

    :ignore
  end
end
