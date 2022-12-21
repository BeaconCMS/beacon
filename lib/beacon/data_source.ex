defmodule Beacon.DataSource do
  @behaviour Beacon.DataSource.Behaviour

  defmodule Error do
    defexception message: "Error in Beacon.DataSource"
  end

  @doc """
  Calls `live_data/3` from Data Source module defined at User's app config.

  This function expects that a module that implements `Beacon.DataSource.Behaviour`
  is defined in the User's application.

  ### Examples

      # lib/my_app/beacon_data_source
      defmodule MyApp.BeaconDataSource do
        @behaviour Beacon.DataSource.Behaviour

        @impl true
        def live_data("my_site", ["home"], _params), do: ["first", "second", "third"]
      end

      # my_app/config/config.exs
      config :beacon, :data_source, MyApp.BeaconDataSource
  """
  def live_data(site, path, params) do
    get_data_source().live_data(site, path, params)
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

  defp get_data_source do
    Application.fetch_env!(:beacon, :data_source)
  end

  defp pop_args_from_stacktrace(stacktrace) do
    Enum.find_value(stacktrace, [], fn
      {_module, :live_data, args, _file_info} -> args
      _ -> []
    end)
  end
end
