defmodule Beacon.ErrorHandlerCompileHook do
  @moduledoc """
  This module can be called with `@before_compile Beacon.ErrorHandlerCompileHook`
  """

  defmacro __before_compile__(_env) do
    quote do
      @set_error_handler_flag Process.flag(:error_handler, Beacon.ErrorHandler)
    end
  end
end
