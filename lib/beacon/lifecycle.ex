defmodule Beacon.Lifecycle do
  @moduledoc """
  Beacon is open for extensibility by allowing users to inject custom steps into its internal lifecycle.

  You can add or overwrite those steps in `t:Beacon.Config.lifecycle/0`.

  Each one of these functions will be called in specific places inside Beacon's lifecycle,
  executing the steps defined in the site config.

  See each function doc for more info and also `Beacon.Config`.
  """
  def fetch_steps!(site, task_name) do
    config = Beacon.Config.fetch!(site)
    Keyword.fetch!(config.lifecycle, task_name)
  end

  def fetch_steps!(config, task_name, type) do
    config
    |> fetch_steps!(task_name)
    |> Enum.find(fn {key, _} -> key == type end)
  end

  def execute_steps(stage, steps, resource, metadata \\ nil)
  def execute_steps(_stage, [], resource, _metadata), do: resource

  def execute_steps(stage, steps, resource, metadata) do
    Enum.reduce_while(steps, resource, fn
      {step, fun}, acc when is_function(fun, 1) ->
        reduce_step(step, fun.(acc))

      {step, fun}, acc when is_function(fun, 2) ->
        reduce_step(step, fun.(acc, metadata))
    end)
  rescue
    exception in Beacon.LoaderError ->
      reraise exception, __STACKTRACE__

    exception ->
      message = """
      stage #{stage} failed with exception:

      #{Exception.format(:error, exception)}

      """

      reraise Beacon.LoaderError, [message: message], __STACKTRACE__
  end

  defp reduce_step(step, result) do
    case result do
      {:cont, _} = acc ->
        acc

      {:halt, %{__exception__: true} = exception} = _acc ->
        message = """
        step #{inspect(step)} halted with exception:

        #{Exception.format(:error, exception)}

        """

        raise Beacon.LoaderError, message

      {:halt, _} = acc ->
        acc

      other ->
        raise Beacon.LoaderError, """
        expected step #{inspect(step)} to return one of the following:

            {:cont, resource}
            {:halt, resource}
            {:halt, exception}

        Got:

            #{inspect(other)}

        """
    end
  end
end
