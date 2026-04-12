defmodule Beacon.GraphQL.ResponseCache do
  @moduledoc false

  @table :beacon_runtime_poc

  @doc """
  Fetch a GraphQL query response from cache, or execute and cache it.

  Uses `Beacon.Cache` for stampede-safe fetching — exactly one process
  executes the fetch function on a cache miss.
  """
  @spec fetch(atom(), binary(), binary(), map(), pos_integer(), fun()) ::
          {:ok, map()} | {:partial, map(), [map()]} | {:error, term()}
  def fetch(site, endpoint_name, query, variables, ttl, fetch_fn) do
    cache_key = derive_key(site, endpoint_name, query, variables)

    Beacon.Cache.fetch(@table, cache_key, fn ->
      result = fetch_fn.()

      case result do
        {:error, _} ->
          # Don't cache errors — raise to prevent Beacon.Cache from storing
          throw({:graphql_error, result})

        _ ->
          result
      end
    end, ttl)
  catch
    {:graphql_error, result} -> result
  end

  @doc """
  Invalidate all cached responses for a specific endpoint.
  """
  @spec invalidate_endpoint(atom(), binary()) :: :ok
  def invalidate_endpoint(site, endpoint_name) do
    pattern = {{site, :graphql_cache, endpoint_name, :_, :_}, :_}
    :ets.match_delete(@table, pattern)
    :ok
  end

  @doc """
  Invalidate a specific cached response.
  """
  @spec invalidate(atom(), binary(), binary(), map()) :: :ok
  def invalidate(site, endpoint_name, query, variables) do
    cache_key = derive_key(site, endpoint_name, query, variables)
    :ets.delete(@table, cache_key)
    :ok
  end

  defp derive_key(site, endpoint_name, query, variables) do
    query_hash = :erlang.phash2(query)
    variables_hash = :erlang.phash2(variables)
    {site, :graphql_cache, endpoint_name, query_hash, variables_hash}
  end
end
