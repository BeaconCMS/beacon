defmodule Beacon.DataStore.PubSubHandler do
  @moduledoc false

  use GenServer
  require Logger

  alias Beacon.DataStore

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  @impl true
  def init(config) do
    {:ok, %{site: config.site, config: config}, {:continue, :subscribe}}
  end

  @impl true
  def handle_continue(:subscribe, %{site: site, config: config} = state) do
    # Subscribe to host-app-defined invalidation topics
    for source <- config.data_sources, topic <- source.invalidate_on do
      full_topic = "beacon:#{site}:data_store:#{topic}"
      Phoenix.PubSub.subscribe(Beacon.PubSub, full_topic)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:invalidate, source_name}, %{site: site} = state) when is_atom(source_name) do
    DataStore.invalidate(site, source_name)
    {:noreply, state}
  end

  @impl true
  def handle_info({:invalidate, source_name, params}, %{site: site} = state) when is_atom(source_name) do
    DataStore.invalidate(site, source_name, params)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
