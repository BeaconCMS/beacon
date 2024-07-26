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

  @doc """
  Logic to validate that a given `Beacon.Lifecycle` was initialized properly, according to the given
  `Beacon.Config`.  A sub-key may be provided if only one lifecycle stage is to be validated, otherwise
  `nil` is expected for the third argument.
  """
  @callback validate_input!(lifecycle :: Lifecycle.t(), config :: Beacon.Config.t(), subkey :: atom()) :: Lifecycle.t()

  @doc """
  Logic to put metadata from a given context into a `Beacon.Lifecycle`.  The `Beacon.Config` will
  also be available here if needed.
  """
  @callback put_metadata(lifecycle :: Lifecycle.t(), config :: Beacon.Config.t(), context :: term()) :: Lifecycle.t()

  @doc """
  After executing all the steps of a `Beacon.Lifecycle`, it is passed here to validate that the output
  is as-expected.  The `Beacon.Config` will also be available here if needed.
  """
  @callback validate_output!(lifecycle :: Lifecycle.t(), config :: Beacon.Config.t(), subkey :: atom()) :: Lifecycle.t()

  @optional_callbacks validate_input!: 3, put_metadata: 3, validate_output!: 3

  @doc """
  Initializes a `Beacon.Lifecycle` with given `lifecycle_name` and `resource`, runs all steps
  for each lifecycle stage, and returns the Lifecycle with result stored in its `:output` key.

  Expects a `provider` which implements callbacks for validation before and after execution,
  as well as the logic for parsing contextual metadata.

  ## Options

    * `:sub_key` - The name of a specific lifecycle stage to execute.  If provided, all other stages
      will be skipped.  Defaults to `nil`, which runs all stages.
    * `context` - Metadata to insert into the Lifecycle for use during execution.  Defaults to `nil`.

  """
  @spec execute(module(), Beacon.Types.Site.t(), atom(), term(), keyword()) :: Lifecycle.t()
  def execute(provider, site, lifecycle_name, resource, opts \\ []) do
    sub_key = Keyword.get(opts, :sub_key)
    context = Keyword.get(opts, :context)
    config = Beacon.Config.fetch!(site)

    %Lifecycle{
      name: lifecycle_name,
      resource: resource
    }
    |> validate_input!(provider, config, sub_key)
    |> put_metadata(provider, config, context)
    |> put_steps(config, sub_key)
    |> execute_steps()
    |> validate_output!(provider, config, sub_key)
  end

  @doc """
  This function delegates to the `validate_input!/3` callback implemented by the `provider` module.

  If the callback is not implemented, this will be a no-op.
  """
  @spec validate_input!(Lifecycle.t(), module(), Beacon.Config.t(), atom()) :: Lifecycle.t()
  def validate_input!(lifecycle, provider, config, sub_key) do
    if Beacon.exported?(provider, :validate_input!, 3) do
      provider.validate_input!(lifecycle, config, sub_key)
    else
      lifecycle
    end
  end

  @doc """
  This function delegates to the `put_metadata/3` callback implemented by the `provider` module.

  If the callback is not implemented, this will be a no-op.
  """
  @spec validate_input!(Lifecycle.t(), module(), Beacon.Config.t(), term()) :: Lifecycle.t()
  def put_metadata(lifecycle, provider, config, context) do
    if Beacon.exported?(provider, :put_metadata, 3) do
      provider.put_metadata(lifecycle, config, context)
    else
      lifecycle
    end
  end

  @doc """
  This function delegates to the `validate_output!/3` callback implemented by the `provider` module.

  If the callback is not implemented, this will be a no-op.
  """
  @spec validate_output!(Lifecycle.t(), module(), Beacon.Config.t(), atom()) :: Lifecycle.t()
  def validate_output!(lifecycle, provider, config, sub_key) do
    if Beacon.exported?(provider, :validate_output!, 3) do
      provider.validate_output!(lifecycle, config, sub_key)
    else
      lifecycle
    end
  end

  @doc """
  Fetches the steps for a given Lifecycle from the provided `Beacon.Config` and puts those
  steps into the Lifecycle.

  A `sub_key` may be provided to only consider the steps for a single lifecycle stage
  """
  @spec put_steps(Lifecycle.t(), Beacon.Config.t(), atom()) :: Lifecycle.t()
  def put_steps(lifecycle, config, sub_key \\ nil) do
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

  @doc """
  Runs all steps in a given Lifecycle.
  """
  @spec execute_steps(Lifecycle.t()) :: Lifecycle.t()
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
