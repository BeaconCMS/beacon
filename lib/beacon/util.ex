defmodule Beacon.Util do
  @default_safe_code_check false

  def safe_code_check!(code) do
    if check_code?() do
      SafeCode.Validator.validate!(code, extra_function_validators: Beacon.Loader.SafeCodeImpl)
    end
  end

  def safe_code_heex_check!(code) do
    if check_code?() do
      SafeCode.Validator.validate_heex!(code, extra_function_validators: Beacon.Loader.SafeCodeImpl)
    end
  end

  defp check_code?, do: get_config(:safe_code_check, @default_safe_code_check)

  def get_config(key, default), do: Application.get_env(:beacon, key, default)

end
