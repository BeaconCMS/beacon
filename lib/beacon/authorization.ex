defmodule Beacon.Authorization do
  @moduledoc false

  @behaviour Beacon.Authorization.Behaviour

  defmodule Error do
    defexception message: "Error in Beacon.Authorization"
  end

  @doc false
  def get_requestor_context(data) do
    user_authorization_source_mod = get_authorization_source()

    if user_authorization_source_mod && is_atom(user_authorization_source_mod) do
      user_authorization_source_mod.get_requestor_context(data)
    else
      nil
    end
  rescue
    error in FunctionClauseError ->
      args = pop_args_from_stacktrace(__STACKTRACE__)
      function_arity = "#{error.function}/#{error.arity}"

      error_message = """
      Could not find #{function_arity} that matches the given args: \
      #{inspect(args)}.

      Make sure you have defined a implemention of Beacon.Authorization.#{function_arity} \
      that matches these args.\
      """

      reraise __MODULE__.Error, [message: error_message], __STACKTRACE__

    error ->
      reraise error, __STACKTRACE__
  end

  def authorized?(requestor_context, operation_context) do
    user_authorization_source_mod = get_authorization_source()

    if user_authorization_source_mod && is_atom(user_authorization_source_mod) do
      user_authorization_source_mod.authorized?(requestor_context, operation_context)
    else
      nil
    end
  rescue
    error in FunctionClauseError ->
      args = pop_args_from_stacktrace(__STACKTRACE__)
      function_arity = "#{error.function}/#{error.arity}"

      error_message = """
      Could not find #{function_arity} that matches the given args: \
      #{inspect(args)}.

      Make sure you have defined a implemention of Beacon.Authorization.#{function_arity} \
      that matches these args.\
      """

      reraise __MODULE__.Error, [message: error_message], __STACKTRACE__

    error ->
      reraise error, __STACKTRACE__
  end

  def authorized?(site, requestor_context, operation_context) do
    user_authorization_source_mod = get_authorization_source()

    if user_authorization_source_mod && is_atom(user_authorization_source_mod) do
      user_authorization_source_mod.authorized?(site, requestor_context, operation_context)
    else
      nil
    end
  rescue
    error in FunctionClauseError ->
      args = pop_args_from_stacktrace(__STACKTRACE__)
      function_arity = "#{error.function}/#{error.arity}"

      error_message = """
      Could not find #{function_arity} that matches the given args: \
      #{inspect(args)}.

      Make sure you have defined a implemention of Beacon.Authorization.#{function_arity} \
      that matches these args.\
      """

      reraise __MODULE__.Error, [message: error_message], __STACKTRACE__

    error ->
      reraise error, __STACKTRACE__
  end

  defp get_authorization_source() do
    :beacon
    |> Application.get_env(:admin, authorization_source: Beacon.Authorization.PassThrough)
    |> Keyword.get(:authorization_source)
  end

  defp pop_args_from_stacktrace(stacktrace) do
    Enum.find_value(stacktrace, [], fn
      {_module, :live_data, args, _file_info} -> args
      _ -> []
    end)
  end
end
