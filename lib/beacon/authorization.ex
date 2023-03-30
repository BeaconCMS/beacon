defmodule Beacon.Authorization do
  @moduledoc false

  alias Beacon.Behaviors.Helpers

  @behaviour Beacon.Authorization.Behaviour

  def get_agent(data) do
    user_authorization_source_mod = get_authorization_source()

    if user_authorization_source_mod && is_atom(user_authorization_source_mod) do
      user_authorization_source_mod.get_agent(data)
    else
      nil
    end
  rescue
    error in FunctionClauseError ->
      Helpers.reraise_function_clause_error(error.function, error.arity, __STACKTRACE__, Beacon.AuthorizationError)

    error ->
      reraise error, __STACKTRACE__
  end

  def authorized?(agent, operation, context) do
    user_authorization_source_mod = get_authorization_source()

    if user_authorization_source_mod && is_atom(user_authorization_source_mod) do
      user_authorization_source_mod.authorized?(agent, operation, context)
    else
      raise """
      authorization source is misconfigured.

      Expected a module implementing Beacon.Authorization.Behaviour callbacks.

      Got: #{inspect(user_authorization_source_mod)}
      """
    end
  rescue
    error in FunctionClauseError ->
      Helpers.reraise_function_clause_error(error.function, error.arity, __STACKTRACE__, Beacon.AuthorizationError)

    error ->
      reraise error, __STACKTRACE__
  end

  defp get_authorization_source do
    case Beacon.Registry.registered_sites() do
      [] ->
        Beacon.Authorization.DefaultPolicy

      [site | _] ->
        Beacon.Registry.config!(site).authorization_source
    end
  end
end
