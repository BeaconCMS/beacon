defmodule Beacon.GraphQL.EndpointCache do
  @moduledoc false

  @table :beacon_runtime_poc

  @doc """
  Get endpoint config from ETS cache, falling back to DB.
  """
  @spec get_endpoint(atom(), binary()) :: {:ok, Beacon.Content.GraphQLEndpoint.t()} | :error
  def get_endpoint(site, endpoint_name) do
    cache_key = {site, :graphql_endpoint, endpoint_name}

    case :ets.lookup(@table, cache_key) do
      [{^cache_key, endpoint}] ->
        {:ok, endpoint}

      [] ->
        case load_from_db(site, endpoint_name) do
          nil -> :error
          endpoint ->
            :ets.insert(@table, {cache_key, endpoint})
            {:ok, endpoint}
        end
    end
  end

  @doc """
  Invalidate a cached endpoint config. Called when endpoint is updated in admin.
  """
  @spec invalidate(atom(), binary()) :: true
  def invalidate(site, endpoint_name) do
    :ets.delete(@table, {site, :graphql_endpoint, endpoint_name})
  end

  @doc """
  Invalidate all cached endpoint configs for a site.
  """
  @spec invalidate_all(atom()) :: true
  def invalidate_all(site) do
    :ets.match_delete(@table, {{site, :graphql_endpoint, :_}, :_})
  end

  defp load_from_db(site, endpoint_name) do
    Beacon.Content.get_graphql_endpoint_by(site, name: endpoint_name)
  end
end
