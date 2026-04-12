defmodule Beacon.GraphQL.OperationAllowlist do
  @moduledoc false

  @table :beacon_runtime_poc

  @doc """
  Set the allowed operations for a GraphQL endpoint.
  Pass `nil` to allow all operations (default behavior).
  """
  @spec set(atom(), binary(), [binary()] | nil) :: :ok
  def set(site, endpoint_name, operations) do
    :ets.insert(@table, {{site, :graphql_allowlist, endpoint_name}, operations})
    :ok
  end

  @doc """
  Check if an operation is allowed for a given endpoint.
  Returns `:ok` if allowed, `{:error, :operation_not_allowed}` if blocked.
  """
  @spec check(atom(), binary(), binary()) :: :ok | {:error, :operation_not_allowed}
  def check(site, endpoint_name, operation_name) do
    case :ets.lookup(@table, {site, :graphql_allowlist, endpoint_name}) do
      [{_, nil}] ->
        # nil means allow all
        :ok

      [{_, allowed}] when is_list(allowed) ->
        if operation_name in allowed, do: :ok, else: {:error, :operation_not_allowed}

      [] ->
        # No allowlist configured — allow all by default
        :ok
    end
  end

  @doc """
  Get the allowlist for an endpoint. Returns `nil` if all operations are allowed.
  """
  @spec get(atom(), binary()) :: [binary()] | nil
  def get(site, endpoint_name) do
    case :ets.lookup(@table, {site, :graphql_allowlist, endpoint_name}) do
      [{_, operations}] -> operations
      [] -> nil
    end
  end
end
