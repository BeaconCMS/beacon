defmodule Beacon.CircuitBreaker do
  @moduledoc false

  # Prevents cascading failures when a page keeps returning 500 errors.
  #
  # When a page raises during mount or render, the circuit trips for that path.
  # Subsequent requests to the same path return an immediate 500 response
  # without executing any page logic, for a configurable TTL (default 60s).
  #
  # Uses ETS for zero-overhead lookups. No GenServer needed.

  @table :beacon_circuit_breaker

  def init do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    end

    :ok
  end

  @doc """
  Check if the circuit is tripped for the given site and path.
  Returns `:ok` if the circuit is closed (request should proceed).
  Returns `{:tripped, seconds_remaining}` if the circuit is open.
  """
  def check(site, path) do
    if :ets.whereis(@table) == :undefined do
      :ok
    else
      case :ets.lookup(@table, {site, path}) do
        [{_, tripped_at, ttl}] ->
          elapsed = System.monotonic_time(:second) - tripped_at

          if elapsed < ttl do
            {:tripped, ttl - elapsed}
          else
            :ets.delete(@table, {site, path})
            :ok
          end

        [] ->
          :ok
      end
    end
  end

  @doc """
  Trip the circuit breaker for the given site and path.
  """
  def trip(site, path, ttl \\ 60) do
    if :ets.whereis(@table) != :undefined do
      :ets.insert(@table, {{site, path}, System.monotonic_time(:second), ttl})
    end

    :ok
  end

  @doc """
  Reset the circuit breaker for the given site and path.
  """
  def reset(site, path) do
    :ets.delete(@table, {site, path})
    :ok
  end
end
