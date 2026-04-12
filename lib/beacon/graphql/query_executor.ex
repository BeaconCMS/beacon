defmodule Beacon.GraphQL.QueryExecutor do
  @moduledoc false

  alias Beacon.GraphQL.Client
  alias Beacon.GraphQL.ResponseCache
  alias Beacon.GraphQL.VariableResolver
  require Logger

  @doc """
  Execute all page queries for a page, respecting dependencies.

  Returns `{assigns_map, endpoint_names_list}`.

  Queries without `depends_on` execute in parallel. Queries with `depends_on`
  execute after their dependency completes, with access to prior results
  for variable resolution.
  """
  @spec execute_page_queries(atom(), [map()], map(), map()) :: {map(), [binary()]}
  def execute_page_queries(site, page_queries, path_params, query_params) do
    if page_queries == [] do
      {%{}, []}
    else
      {layers, _} = topological_sort(page_queries)
      {assigns, endpoint_names} = execute_layers(site, layers, path_params, query_params)
      {assigns, Enum.uniq(endpoint_names)}
    end
  end

  # Sort queries into execution layers. Layer 0 has no dependencies,
  # layer 1 depends on layer 0, etc.
  defp topological_sort(queries) do
    {layers, placed} =
      Enum.reduce_while(1..100, {[], MapSet.new()}, fn _i, {layers, placed} ->
        # Find queries whose dependencies are already placed (or have none)
        ready =
          Enum.filter(queries, fn q ->
            not MapSet.member?(placed, q.result_alias) and
              (is_nil(q.depends_on) or MapSet.member?(placed, q.depends_on))
          end)

        if ready == [] do
          # Either all placed, or circular dependency
          {:halt, {layers, placed}}
        else
          new_placed = Enum.reduce(ready, placed, &MapSet.put(&2, &1.result_alias))
          {:cont, {layers ++ [ready], new_placed}}
        end
      end)

    # Warn about unplaced queries (circular deps)
    all_aliases = MapSet.new(queries, & &1.result_alias)
    unplaced = MapSet.difference(all_aliases, placed)

    if MapSet.size(unplaced) > 0 do
      Logger.warning("[Beacon.GraphQL] Circular dependency detected in page queries: #{inspect(MapSet.to_list(unplaced))}")
    end

    {layers, placed}
  end

  defp execute_layers(site, layers, path_params, query_params) do
    Enum.reduce(layers, {%{}, []}, fn layer, {prior_results, endpoint_names} ->
      # Execute all queries in this layer in parallel
      results =
        layer
        |> Task.async_stream(
          fn query ->
            variables = VariableResolver.resolve(
              query.variable_bindings || %{},
              path_params,
              query_params,
              prior_results
            )

            result = execute_cached(site, query, variables)
            {query.result_alias, query.endpoint_name, result}
          end,
          max_concurrency: max(length(layer), 1),
          timeout: 15_000
        )
        |> Enum.map(fn
          {:ok, result} -> result
          {:exit, reason} ->
            Logger.warning("[Beacon.GraphQL] Query execution failed: #{inspect(reason)}")
            {nil, nil, {:error, {:task_failed, reason}}}
        end)

      # Merge results into prior_results and collect endpoint names
      Enum.reduce(results, {prior_results, endpoint_names}, fn
        {nil, _, _}, acc ->
          acc

        {result_alias, endpoint_name, {:ok, data}}, {acc, names} ->
          {Map.put(acc, result_alias, unwrap_response(data)), [endpoint_name | names]}

        {result_alias, endpoint_name, {:partial, data, errors}}, {acc, names} ->
          Logger.warning("[Beacon.GraphQL] Partial response for #{result_alias}: #{inspect(errors)}")
          {Map.put(acc, result_alias, unwrap_response(data)), [endpoint_name | names]}

        {result_alias, endpoint_name, {:error, reason}}, {acc, names} ->
          Logger.warning("[Beacon.GraphQL] Query #{result_alias} failed: #{inspect(reason)}")
          {Map.put(acc, result_alias, nil), [endpoint_name | names]}
      end)
    end)
  end

  defp execute_cached(site, query, variables) do
    endpoint_name = query.endpoint_name

    # Get TTL using Beacon's hierarchical TTL resolution:
    # 1. endpoint-specific default_ttl, 2. site-level cache_ttls[:graphql], 3. site-level cache_ttl
    ttl =
      case Beacon.GraphQL.EndpointCache.get_endpoint(site, endpoint_name) do
        {:ok, endpoint} ->
          config = Beacon.Config.fetch!(site)
          Map.get(config.cache_ttls, :graphql, endpoint.default_ttl || config.cache_ttl)
        :error ->
          config = Beacon.Config.fetch!(site)
          Map.get(config.cache_ttls, :graphql, config.cache_ttl)
      end

    ResponseCache.fetch(site, endpoint_name, query.query_string, variables, ttl, fn ->
      Client.execute(site, endpoint_name, query.query_string, variables)
    end)
  end

  # GraphQL responses come as %{"queryName" => value}. When there's a single
  # top-level key, unwrap to just the value so templates get the data directly
  # (e.g., @featured_links = [...] instead of %{"featuredLinks" => [...]}).
  defp unwrap_response(%{} = data) when map_size(data) == 1 do
    data |> Map.values() |> hd()
  end

  defp unwrap_response(data), do: data
end
