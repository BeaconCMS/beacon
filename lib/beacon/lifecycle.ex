defmodule Beacon.Lifecycle do
  @moduledoc """
  Beacon is open for extensibility by allowing users to inject custom steps into its internal lifecycle.

  You can add or overwrite those steps in `t:Beacon.Config.lifecycle/0`.

  Each one of these functions will be called in specific places inside Beacon's lifecycle,
  executing the steps defined in the site config.

  See each function doc for more info and also `Beacon.Config`.
  """
  alias Beacon.Lifecycle

  defstruct name: nil, steps: [], resource: nil, metadata: nil, output: nil

  @type t :: %__MODULE__{
          name: atom(),
          steps: list(),
          resource: term(),
          metadata: term(),
          output: term()
        }

  @callback validate_input!(Lifecycle.t(), Beacon.Config.t(), atom()) :: Lifecycle.t()
  @callback put_metadata(Lifecycle.t(), Beacon.Config.t(), term()) :: Lifecycle.t()
  @callback validate_output!(Lifecycle.t(), Beacon.Config.t(), atom()) :: Lifecycle.t()

  @optional_callbacks validate_input!: 3, put_metadata: 3, validate_output!: 3

  def execute(provider, site, lifecycle, resource, opts \\ []) do
    sub_key = Keyword.get(opts, :sub_key)
    context = Keyword.get(opts, :context)
    config = Beacon.Config.fetch!(site)

    %Lifecycle{
      name: lifecycle,
      resource: resource
    }
    |> validate_input!(provider, config, sub_key)
    |> put_metadata(provider, config, context)
    |> put_steps(config, sub_key)
    |> execute_steps()
    |> validate_output!(provider, config, sub_key)
  end

  def validate_input!(lifecycle, provider, config, sub_key) do
    if Beacon.exported?(provider, :validate_input!, 3) do
      provider.validate_input!(lifecycle, config, sub_key)
    else
      lifecycle
    end
  end

  def put_metadata(lifecycle, provider, config, context) do
    if Beacon.exported?(provider, :put_metadata, 3) do
      provider.put_metadata(lifecycle, config, context)
    else
      lifecycle
    end
  end

  def validate_output!(lifecycle, provider, config, sub_key) do
    if Beacon.exported?(provider, :validate_output!, 3) do
      provider.validate_output!(lifecycle, config, sub_key)
    else
      lifecycle
    end
  end

  def put_steps(lifecycle, config, sub_key) do
    steps_or_config_list = Keyword.fetch!(config.lifecycle, lifecycle.name)

    steps =
      case sub_key do
        nil ->
          steps_or_config_list

        sub_key ->
          {_, steps} = Enum.find(steps_or_config_list, fn {key, _} -> key == sub_key end)
          steps
      end

    %{lifecycle | steps: steps}
  end

  def execute_steps(%Lifecycle{steps: [], resource: resource} = lifecycle) do
    %{lifecycle | output: resource}
  end

  def execute_steps(%Lifecycle{steps: steps, name: name, resource: resource, metadata: metadata} = lifecycle) do
    output =
      Enum.reduce_while(steps, resource, fn
        {step, fun}, acc when is_function(fun, 1) ->
          reduce_step(step, fun.(acc))

        {step, fun}, acc when is_function(fun, 2) ->
          reduce_step(step, fun.(acc, metadata))
      end)

    %{lifecycle | output: output}
  rescue
    exception in Beacon.LoaderError ->
      reraise exception, __STACKTRACE__

    exception ->
      message = """
      #{name} lifecycle failed with exception:

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
