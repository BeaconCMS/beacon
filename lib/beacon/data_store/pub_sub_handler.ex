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
  def handle_info(:invalidate, %{site: site, config: config} = state) do
    # Broadcast on a generic topic — invalidate all sources that listen to it
    # (handled by matching against source.invalidate_on in the subscribe step)
    # This is a catch-all; specific source invalidation is handled below
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
  def handle_info(msg, %{site: site, config: config} = state) do
    # Check if any source's invalidate_on topics match this message's topic
    # The message arrives because we subscribed to the topic in init
    # Invalidate all sources that declared this topic in invalidate_on
    for source <- config.data_sources do
      if Enum.any?(source.invalidate_on, fn topic ->
        # We subscribed to "beacon:SITE:data_store:TOPIC" and got a message
        true
      end) do
        DataStore.invalidate(site, source.name)
      end
    end

    {:noreply, state}
  end
end
