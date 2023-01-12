defmodule Beacon.DataSource do
  @moduledoc false

  @behaviour Beacon.DataSource.Behaviour

  defmodule Error do
    defexception message: "Error in Beacon.DataSource"
  end

  @doc false
  def live_data(site, path, params) do
    get_data_source(site).live_data(site, path, params)
  rescue
    error in FunctionClauseError ->
      args = pop_args_from_stacktrace(__STACKTRACE__)
      function_arity = "#{error.function}/#{error.arity}"

      error_message = """
      Could not find #{function_arity} that matches the given args: \
      #{inspect(args)}.

      Make sure you have defined a implemention of Beacon.DataSource.#{function_arity} \
      that matches these args.\
      """

      reraise __MODULE__.Error, [message: error_message], __STACKTRACE__

    error ->
      reraise error, __STACKTRACE__
  end

  defp get_data_source(site) do
    :persistent_term.get({:beacon, site, "data_source"})
  end

  defp pop_args_from_stacktrace(stacktrace) do
    Enum.find_value(stacktrace, [], fn
      {_module, :live_data, args, _file_info} -> args
      _ -> []
    end)
  end
end
