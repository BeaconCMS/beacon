defmodule Beacon.GraphQL.Client do
  @moduledoc false

  alias Beacon.Content.GraphQLEndpoint
  alias Beacon.GraphQL.EndpointCache
  alias Beacon.GraphQL.OperationAllowlist

  @doc """
  Execute a GraphQL query/mutation against a named endpoint.

  Checks the circuit breaker before executing. If the endpoint has been
  failing, returns an immediate error without making the HTTP call.
  """
  @spec execute(atom(), binary(), binary(), map(), keyword()) ::
          {:ok, map()} | {:partial, map(), [map()]} | {:error, term()}
  def execute(site, endpoint_name, query, variables \\ %{}, opts \\ []) do
    # Check circuit breaker for this endpoint
    breaker_key = "graphql:#{endpoint_name}"

    case Beacon.CircuitBreaker.check(site, breaker_key) do
      {:tripped, remaining} ->
        {:error, {:circuit_open, endpoint_name, remaining}}

      :ok ->
        with {:ok, endpoint} <- EndpointCache.get_endpoint(site, endpoint_name),
             :ok <- OperationAllowlist.check(site, endpoint_name, extract_operation_name(query)) do
          result = do_execute(endpoint, query, variables, opts)

          # Trip circuit on network/server errors
          case result do
            {:error, {:network, _}} ->
              ttl = endpoint.timeout_ms |> div(1000) |> max(30)
              Beacon.CircuitBreaker.trip(site, breaker_key, ttl)

            {:error, {:http, status, _}} when status >= 500 ->
              Beacon.CircuitBreaker.trip(site, breaker_key, 30)

            _ ->
              :ok
          end

          result
        else
          :error -> {:error, {:endpoint_not_found, endpoint_name}}
          {:error, :operation_not_allowed} -> {:error, {:operation_not_allowed, endpoint_name}}
        end
    end
  end

  @doc """
  Execute multiple independent queries in parallel against their respective endpoints.
  """
  @spec execute_batch(atom(), [{binary(), binary(), map()}], keyword()) ::
          [{:ok, map()} | {:partial, map(), [map()]} | {:error, term()}]
  def execute_batch(site, queries, opts \\ []) do
    queries
    |> Task.async_stream(
      fn {endpoint_name, query, variables} ->
        execute(site, endpoint_name, query, variables, opts)
      end,
      max_concurrency: length(queries),
      timeout: Keyword.get(opts, :timeout, 15_000)
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, reason} -> {:error, {:task_failed, reason}}
    end)
  end

  @doc """
  Execute a raw query against an endpoint struct directly.
  Used internally and by the introspection engine. Bypasses circuit breaker.
  """
  @spec execute_raw(GraphQLEndpoint.t(), binary(), map(), keyword()) ::
          {:ok, map()} | {:partial, map(), [map()]} | {:error, term()}
  def execute_raw(%GraphQLEndpoint{} = endpoint, query, variables \\ %{}, opts \\ []) do
    do_execute(endpoint, query, variables, opts)
  end

  defp do_execute(%GraphQLEndpoint{} = endpoint, query, variables, opts) do
    timeout = Keyword.get(opts, :timeout, endpoint.timeout_ms || 10_000)

    body = %{query: query}
    body = if variables == %{}, do: body, else: Map.put(body, :variables, variables)

    headers = auth_headers(endpoint)

    # Use a dedicated Finch pool for GraphQL requests to avoid connection
    # pool exhaustion when the server calls its own GraphQL endpoint
    # (self-call during page rendering).
    case Req.post(endpoint.url,
           json: body,
           headers: headers,
           receive_timeout: timeout,
           retry: :transient,
           max_retries: endpoint.max_retries || 2,
           finch: Beacon.Finch
         ) do
      {:ok, %{status: 200, body: %{"data" => data, "errors" => errors}}} when is_list(errors) and errors != [] ->
        {:partial, data, errors}

      {:ok, %{status: 200, body: %{"data" => data}}} ->
        {:ok, data}

      {:ok, %{status: 200, body: %{"errors" => errors}}} ->
        {:error, {:graphql, errors}}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http, status, body}}

      {:error, exception} ->
        {:error, {:network, exception}}
    end
  end

  defp extract_operation_name(query) when is_binary(query) do
    case Regex.run(~r/(?:query|mutation|subscription)\s+(\w+)/, query) do
      [_, name] -> name
      _ -> query
    end
  end

  defp auth_headers(%GraphQLEndpoint{auth_type: "bearer", auth_value_encrypted: token})
       when is_binary(token) and token != "" do
    [{"authorization", "Bearer #{token}"}]
  end

  defp auth_headers(%GraphQLEndpoint{auth_type: "header", auth_header: header, auth_value_encrypted: value})
       when is_binary(header) and is_binary(value) do
    [{header, value}]
  end

  defp auth_headers(_), do: []
end
