defmodule Beacon.Behaviors.Helpers do
  @moduledoc false

  def reraise_function_clause_error(function, arity, stacktrace, exception) do
    args = pop_args_from_stacktrace(stacktrace)
    function_arity = "#{function}/#{arity}"

    error_message = """
    Could not find #{function_arity} that matches the given args: \
    #{inspect(args)}.

    Make sure you have defined a implementation of Beacon.Authorization.#{function_arity} \
    that matches these args.\
    """

    reraise exception, [message: error_message], stacktrace
  end

  defp pop_args_from_stacktrace(stacktrace) do
    Enum.find_value(stacktrace, [], fn
      {_module, :live_data, args, _file_info} -> args
      _ -> []
    end)
  end
end
