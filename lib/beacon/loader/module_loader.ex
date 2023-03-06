defmodule Beacon.Loader.ModuleLoader do
  def load(module, ast) do
    :code.delete(module)
    :code.purge(module)

    a = System.monotonic_time(:millisecond)
    Code.compile_quoted(ast)
    b = System.monotonic_time(:millisecond)
    IO.inspect(b - a, label: "Compile time")
    {:module, ^module} = Code.ensure_loaded(module)
    :ok
  end

  def maybe_import_my_component(component_module, _functions) do
    quote do
      import unquote(component_module), only: [my_component: 2]
    end
  end
end
