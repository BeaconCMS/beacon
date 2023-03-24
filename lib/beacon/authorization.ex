defmodule Beacon.Authorization do
  @moduledoc false

  alias Beacon.Behaviors.Helpers
  alias Beacon.Registry

  @behaviour Beacon.Authorization.Behaviour

  defmodule Error do
    defexception message: "Error in Beacon.Authorization"
  end

  @doc false
  def get_agent(data) do
    user_authorization_source_mod = get_authorization_source()

    if user_authorization_source_mod && is_atom(user_authorization_source_mod) do
      user_authorization_source_mod.get_agent(data)
    else
      nil
    end
  rescue
    error in FunctionClauseError ->
      module = __MODULE__
      trace = __STACKTRACE__
      Helpers.reraise_function_clause_error(module, error, trace)

    error ->
      reraise error, __STACKTRACE__
  end

  def authorized?(agent, operation, context) do
    user_authorization_source_mod = get_authorization_source()

    if user_authorization_source_mod && is_atom(user_authorization_source_mod) do
      user_authorization_source_mod.authorized?(agent, operation, context)
    else
      raise "Authorization source is misconfigured. VALUE: #{user_authorization_source_mod}"
    end
  rescue
    error in FunctionClauseError ->
      module = __MODULE__
      trace = __STACKTRACE__
      Helpers.reraise_function_clause_error(module, error, trace)

    error ->
      reraise error, __STACKTRACE__
  end

  defp get_authorization_source do
    case Registry.registered_sites() do
      [] ->
        Beacon.Authorization.DefaultPolicy

      [site | _] ->
        Registry.config!(site).authorization_source
    end
  end
end
