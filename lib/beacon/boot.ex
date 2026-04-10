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

  def init(%{site: site, mode: mode} = config) when is_atom(site) and mode in [:manual, :testing] do
    Logger.debug("Beacon.Boot is disabled for site #{site} on #{mode} mode")

    if config.data_sources != [] do
      Beacon.DataStore.register(site, config.data_sources)
    end

    :ignore
  end

  def init(%{site: site, mode: :live} = config) when is_atom(site) do
    Beacon.RuntimeRenderer.init()

    # Register data sources from config into ETS
    if config.data_sources != [] do
      Beacon.DataStore.register(site, config.data_sources)
    end

    :persistent_term.put({Beacon, site, :boot_ready}, true)
    Logger.info("Beacon.Boot site #{site} ready (lazy loading)")
    :ignore
  end
end
