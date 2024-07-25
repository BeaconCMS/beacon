defmodule Beacon.Authorization do
  @moduledoc false

  # TODO: review authz
  # """
  # Protects resources by authorizing agents to perform operations in Beacon.

  # An agent might be a user, a system, or any entity that is performing an operation.

  # Executes the authorization rules defined by `Beacon.Authorization.Policy`.

  # Most of those calls are done in Beacon LiveAdmin or internally in Beacon contexts so you don't need to call them directly,
  # unless you're building a custom admin page or custom logic then you can rely on this module
  # to get the agent (who is performing the operation) with `get_agent/2` and check if the agent
  # is authorized to perform such operation with `authorized?/4`.
  # """

  alias Beacon.Behaviors.Helpers

  @spec get_agent(Beacon.Types.site(), any()) :: any() | nil
  def get_agent(site, payload) when is_atom(site) do
    site
    |> get_authorization_source!()
    |> do_get_agent(payload)
  end

  defp do_get_agent(nil = _authorization_source, _payload), do: nil

  defp do_get_agent(authorization_source, payload) do
    if Beacon.exported?(authorization_source, :get_agent, 1) do
      authorization_source.get_agent(payload)
    else
      nil
    end
  rescue
    error in FunctionClauseError ->
      Helpers.reraise_function_clause_error(error.function, error.arity, __STACKTRACE__, Beacon.AuthorizationError)

    error ->
      reraise error, __STACKTRACE__
  end

  @spec authorized?(Beacon.Types.site(), any(), atom(), map()) :: boolean()
  def authorized?(site, agent, operation, context) when is_atom(site) do
    site
    |> get_authorization_source!()
    |> do_authorized?(agent, operation, context)
  end

  defp do_authorized?(authorization_source, agent, operation, context) do
    if Beacon.exported?(authorization_source, :authorized?, 3) do
      authorization_source.authorized?(agent, operation, context)
    else
      raise """
      authorization source is misconfigured.

      Expected a module implementing Beacon.Authorization.Policy callbacks.

      Got: #{inspect(authorization_source)}
      """
    end
  rescue
    error in FunctionClauseError ->
      Helpers.reraise_function_clause_error(error.function, error.arity, __STACKTRACE__, Beacon.AuthorizationError)

    error ->
      reraise error, __STACKTRACE__
  end

  defp get_authorization_source!(site), do: Beacon.Config.fetch!(site).authorization_source
end
