defmodule Beacon.SafeCodeImpl do
  @moduledoc false

  @behaviour SafeCode.Validator.FunctionValidators.Behaviour

  @impl true
  def safe_function?(:my_component), do: true
  def safe_function?(_), do: false

  @impl true
  def safe_module_function?(_, _), do: false
end
