defmodule Beacon.DataSource do
  @moduledoc false

  @behaviour Beacon.DataSource.Behaviour

  defmodule Error do
    defexception message: "Error in Beacon.DataSource"
  end

  @doc false
  def live_data(site, path, params) do
    user_data_source_mod = get_data_source(site)

    if user_data_source_mod && function_exported?(user_data_source_mod, :live_data, 3) do
      user_data_source_mod.live_data(site, path, params)
    else
      %{}
    end
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

  def page_title(site, path, params, page_title) do
    user_data_source_mod = get_data_source(site)

    if user_data_source_mod && function_exported?(user_data_source_mod, :page_title, 4) do
      user_data_source_mod.page_title(site, path, params, page_title)
    else
      page_title
    end
  rescue
    _error in FunctionClauseError ->
      error_message = """
      TODO
      """

      reraise __MODULE__.Error, [message: error_message], __STACKTRACE__
    error ->
      reraise error, __STACKTRACE__
  end

  defp get_data_source(site) do
    Beacon.Config.fetch!(site).data_source
  end

  defp pop_args_from_stacktrace(stacktrace) do
    Enum.find_value(stacktrace, [], fn
      {_module, :live_data, args, _file_info} -> args
      _ -> []
    end)
  end
end
