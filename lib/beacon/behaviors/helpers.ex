defmodule Beacon.Behaviors.Helpers do
  def reraise_function_clause_error(module, error, trace) do
    args = pop_args_from_stacktrace(trace)

    function_arity = "#{error.function}/#{error.arity}"

    error_message = """
    Could not find #{function_arity} that matches the given args: \
    #{inspect(args)}.

    Make sure you have defined a implemention of Beacon.Authorization.#{function_arity} \
    that matches these args.\
    """

    reraise Module.concat(module, Error), [message: error_message], trace
  end

  defp pop_args_from_stacktrace(stacktrace) do
    Enum.find_value(stacktrace, [], fn
      {_module, :live_data, args, _file_info} -> args
      _ -> []
    end)
  end
end
