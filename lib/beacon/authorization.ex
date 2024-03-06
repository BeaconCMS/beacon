defmodule Beacon.Authorization do
  @moduledoc """
  TODO
  """

  alias Beacon.Behaviors.Helpers

  def get_agent(site, data) when is_atom(site) do
    authorization_source = get_authorization_source(site)
    do_get_agent(authorization_source, data)
  end

  defp do_get_agent(nil = _authorization_source, _data), do: nil

  defp do_get_agent(authorization_source, data) do
    if Beacon.Loader.exported?(authorization_source, :get_agent, 1) do
      authorization_source.get_agent(data)
    else
      nil
    end
  rescue
    error in FunctionClauseError ->
      Helpers.reraise_function_clause_error(error.function, error.arity, __STACKTRACE__, Beacon.AuthorizationError)

    error ->
      reraise error, __STACKTRACE__
  end

  def authorized?(site, agent, operation, context) do
    authorization_source = get_authorization_source(site)
    do_authorized?(authorization_source, agent, operation, context)
  end

  defp do_authorized?(authorization_source, agent, operation, context) do
    if Beacon.Loader.exported?(authorization_source, :authorized?, 3) do
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

  defp get_authorization_source(site) do
    Beacon.Registry.config!(site).authorization_source
  end
end
