defmodule Beacon.Loader.ModuleLoader do
  def load(module, code_string) do
    :code.delete(module)
    :code.purge(module)

    Code.compile_string(code_string)
    {:module, ^module} = Code.ensure_loaded(module)
    :ok
  end
end
