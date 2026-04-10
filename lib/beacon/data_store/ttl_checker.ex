defmodule Beacon.DataStore.TtlChecker do
  @moduledoc false

  use GenServer
  require Logger

  alias Beacon.DataStore

  @check_interval 10_000  # Check every 10 seconds

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  @impl true
  def init(config) do
    schedule_check()
    {:ok, %{site: config.site}}
  end

  @impl true
  def handle_info(:check_ttl, %{site: site} = state) do
    check_and_refresh(site)
    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_ttl, @check_interval)
  end

  defp check_and_refresh(site) do
    table = :beacon_runtime_poc
    now = System.monotonic_time(:second)

    # Scan all cached data store entries for this site
    pattern = {{site, :data_store, :cache, :"$1", :"$2"}, {:"$3", :"$4"}}
    entries = :ets.match(table, pattern)

    for [source_name, cache_key, _value, inserted_at] <- entries do
      source = DataStore.get_source(site, source_name)

      if source do
        ttl_seconds = div(source.ttl, 1000)

        if now - inserted_at >= ttl_seconds do
          # Entry expired — re-fetch and broadcast
          ets_key = {site, :data_store, :cache, source_name, cache_key}
          :ets.delete(table, ets_key)

          # Re-fetch in a Task to avoid blocking the checker
          Task.start(fn ->
            try do
              DataStore.invalidate(site, source_name)
            rescue
              e -> Logger.error("[DataStore.TtlChecker] Failed to refresh #{source_name}: #{Exception.message(e)}")
            end
          end)
        end
      end
    end
  end
end
