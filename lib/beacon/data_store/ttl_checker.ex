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

    # Scan all cached data store entries for this site.
    # ETS match variables must be charlists: '$1', '$2', etc.
    # Values are stored as {value, inserted_at} tuples by Beacon.Cache.
    pattern = {{site, :data_store, :cache, :"$1", :"$2"}, {:"$3", :"$4"}}
    entries = :ets.match(table, pattern)

    task_supervisor = Beacon.Registry.via({site, TaskSupervisor})

    for [source_name, cache_key, _value, inserted_at] <- entries do
      source = DataStore.get_source(site, source_name)

      if source do
        ttl_seconds = div(source.ttl, 1000)

        if now - inserted_at >= ttl_seconds do
          # Entry expired — delete this specific entry and re-fetch
          ets_key = {site, :data_store, :cache, source_name, cache_key}
          :ets.delete(table, ets_key)

          # Re-fetch under the site's Task.Supervisor to limit concurrency
          Task.Supervisor.start_child(task_supervisor, fn ->
            try do
              # Re-fetch this specific cache key by calling fetch, which will
              # execute the fetcher and repopulate the cache entry
              DataStore.fetch(site, source_name, %{})

              # Broadcast invalidation for this specific source so connected
              # LiveViews re-render with the fresh data
              DataStore.broadcast_invalidation(site, source_name)
            rescue
              e -> Logger.error("[DataStore.TtlChecker] Failed to refresh #{source_name}/#{inspect(cache_key)}: #{Exception.message(e)}")
            end
          end)
        end
      end
    end
  end
end
