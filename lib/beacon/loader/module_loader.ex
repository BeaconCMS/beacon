defmodule Beacon.Loader.ModuleLoader do
  def load(module, ast) do
    :code.delete(module)
    :code.purge(module)
    [{^module, _}] = Code.compile_quoted(ast)
    {:module, ^module} = Code.ensure_loaded(module)

    :ok
  end

  def maybe_import_my_component(_component_module, [] = _functions) do
  end

  def maybe_import_my_component(component_module, functions) do
    # TODO: early return
    {_new_ast, present} =
      Macro.prewalk(functions, false, fn
        {:my_component, _, _} = node, _acc -> {node, true}
        node, true -> {node, true}
        node, false -> {node, false}
      end)

    if present do
      quote do
        import unquote(component_module), only: [my_component: 2]
      end
    end
  end
end
