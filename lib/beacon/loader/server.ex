defmodule Beacon.Loader.Server do
  @moduledoc false

  use GenServer
  require Logger
  alias Beacon.Loader.DBLoader
  alias Beacon.Registry

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  def reload_from_db do
    for site <- Registry.registered_sites() do
      reload_from_db(site)
    end
  end

  def reload_from_db(site) do
    config = Beacon.Config.fetch!(site)
    GenServer.call(name(config.site), {:reload_from_db, config.site})
  end

  def init(config) do
    {:ok, config, {:continue, :load_from_db}}
  end

  def handle_continue(:load_from_db, config) do
    load_from_db(config.site)
    {:noreply, config, :hibernate}
  end

  def handle_call({:reload_from_db, site}, _from, config) do
    load_from_db(site)
    {:reply, :ok, config, :hibernate}
  end

  defp load_from_db(site) do
    DBLoader.load_from_db(site)
  end

  defp name(site) do
    Registry.via({site, __MODULE__})
  end
end
