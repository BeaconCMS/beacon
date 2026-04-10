defmodule Beacon.DataStore do
  @moduledoc """
  Universal data layer for Beacon sites.

  Data sources are registered at config time and fetched at render time
  with ETS-backed caching, stampede protection, and automatic LiveView
  re-rendering on invalidation.

  ## Registering Data Sources

  Data sources are defined in the site config:

      {Beacon, sites: [[
        site: :my_site,
        data_sources: [
          [name: :posts, fetch: {MyApp.Blog, :list_posts, [:filter]}, ttl: :timer.hours(1)],
          [name: :post, fetch: {MyApp.Blog, :get_by_slug, [:slug]}, ttl: :timer.hours(6)]
        ]
      ]]}

  ## Fetching

      Beacon.DataStore.fetch(:my_site, :posts, %{filter: "elixir"})

  Returns cached data on hit, or calls the fetcher on miss with stampede protection.

  ## Invalidation

  Three mechanisms:

    1. **Explicit**: `Beacon.DataStore.invalidate(:my_site, :posts)`
    2. **PubSub**: Host app broadcasts, Beacon auto-invalidates sources with matching `invalidate_on`
    3. **TTL**: Active expiry — periodic checker re-fetches and pushes updates to connected LiveViews

  """

  @table :beacon_runtime_poc
  @pubsub Beacon.PubSub

  # ---------------------------------------------------------------------------
  # Registration
  # ---------------------------------------------------------------------------

  @doc """
  Registers data source definitions for a site into ETS.
  Called internally during site boot.
  """
  @spec register(atom(), [Beacon.DataStore.Source.t()]) :: :ok
  def register(site, sources) when is_atom(site) and is_list(sources) do
    source_map = Map.new(sources, fn source -> {source.name, source} end)
    :ets.insert(@table, {{site, :data_store, :sources}, source_map})
    :ok
  end

  @doc """
  Returns the map of registered sources for a site, or empty map.
  """
  @spec get_sources(atom()) :: %{atom() => Beacon.DataStore.Source.t()}
  def get_sources(site) do
    case :ets.lookup(@table, {site, :data_store, :sources}) do
      [{_, sources}] -> sources
      [] -> %{}
    end
  end

  @doc """
  Returns a single source definition by name, or nil.
  """
  @spec get_source(atom(), atom()) :: Beacon.DataStore.Source.t() | nil
  def get_source(site, source_name) do
    get_sources(site) |> Map.get(source_name)
  end

  @doc """
  Lists all registered data source names for a site.
  """
  @spec list_sources(atom()) :: [atom()]
  def list_sources(site) do
    get_sources(site) |> Map.keys()
  end

  # ---------------------------------------------------------------------------
  # Fetching
  # ---------------------------------------------------------------------------

  @doc """
  Fetches data for a named source with the given params.

  On cache hit, returns the cached value immediately. On cache miss,
  exactly one process executes the fetcher while concurrent callers wait
  (stampede protection via `Beacon.Cache`).
  """
  @spec fetch(atom(), atom(), map()) :: term()
  def fetch(site, source_name, params \\ %{}) do
    source = get_source(site, source_name) || raise "unknown data source #{inspect(source_name)} for site #{site}"
    cache_key = derive_cache_key(source, params)
    ets_key = {site, :data_store, :cache, source_name, cache_key}

    # Convert TTL from ms to seconds for Beacon.Cache
    ttl_seconds = div(source.ttl, 1000)

    Beacon.Cache.fetch(@table, ets_key, fn ->
      execute_fetcher(source, params)
    end, ttl_seconds)
  end

  # ---------------------------------------------------------------------------
  # Invalidation
  # ---------------------------------------------------------------------------

  @doc """
  Invalidates ALL cached entries for a data source.
  Busts the cache and broadcasts to all subscribed LiveViews.
  """
  @spec invalidate(atom(), atom()) :: :ok
  def invalidate(site, source_name) do
    :ets.match_delete(@table, {{site, :data_store, :cache, source_name, :_}, :_})
    broadcast_invalidation(site, source_name)
    # Cascade to page render cache — invalidate all pages using this data source
    Beacon.PageRenderCache.invalidate_by_data_source(site, source_name)
    :ok
  end

  @doc """
  Invalidates a specific cached entry for a data source (specific params).
  """
  @spec invalidate(atom(), atom(), map()) :: :ok
  def invalidate(site, source_name, params) do
    source = get_source(site, source_name)

    if source do
      cache_key = derive_cache_key(source, params)
      :ets.delete(@table, {site, :data_store, :cache, source_name, cache_key})
    end

    broadcast_invalidation(site, source_name, params)
    # Cascade to page render cache — invalidate all pages using this data source
    Beacon.PageRenderCache.invalidate_by_data_source(site, source_name)
    :ok
  end

  # ---------------------------------------------------------------------------
  # PubSub Subscription
  # ---------------------------------------------------------------------------

  @doc """
  Subscribes the calling process to invalidation events for a data source.
  """
  @spec subscribe(atom(), atom()) :: :ok
  def subscribe(site, source_name) do
    Phoenix.PubSub.subscribe(@pubsub, topic(site, source_name))
  end

  @doc """
  Unsubscribes the calling process from a data source's invalidation events.
  """
  @spec unsubscribe(atom(), atom()) :: :ok
  def unsubscribe(site, source_name) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(site, source_name))
  end

  # ---------------------------------------------------------------------------
  # Internal
  # ---------------------------------------------------------------------------

  defp topic(site, source_name) do
    "beacon:#{site}:data_store:#{source_name}"
  end

  @doc false
  def broadcast_invalidation(site, source_name) do
    Phoenix.PubSub.broadcast(@pubsub, topic(site, source_name), {:beacon_data_store_invalidated, source_name})
  end

  @doc false
  def broadcast_invalidation(site, source_name, params) do
    Phoenix.PubSub.broadcast(@pubsub, topic(site, source_name), {:beacon_data_store_invalidated, source_name, params})
  end

  defp derive_cache_key(source, params) do
    case source.cache_key do
      :params_hash -> :erlang.phash2(params)
      fun when is_function(fun, 1) -> fun.(params)
    end
  end

  defp execute_fetcher(source, params) do
    case source.fetch do
      {mod, fun, arg_keys} when is_atom(mod) and is_atom(fun) and is_list(arg_keys) ->
        args =
          if arg_keys == [] do
            []
          else
            # Build a single map with only the requested keys and pass it
            arg_map = Map.take(params, arg_keys)
            [arg_map]
          end

        apply(mod, fun, args)

      fun when is_function(fun, 1) ->
        fun.(params)

      fun when is_function(fun, 0) ->
        fun.()
    end
  end
end
