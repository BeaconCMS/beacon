defmodule Beacon.Loader.ComponentModuleLoader do
  require Logger

  alias Beacon.Components.Component
  alias Beacon.Loader.ModuleLoader

  def load_components(_site, [] = _components) do
    :skip
  end

  def load_components(site, components) do
    component_module = Beacon.Loader.component_module_for_site(site)

    render_functions = Enum.map(components, &render_component/1)

    ast = render(component_module, render_functions)
    :ok = ModuleLoader.load(component_module, ast)
    {:ok, ast}
  end

  defp render(component_module, render_functions) do
    quote do
      defmodule unquote(component_module) do
        import Phoenix.Component
        use Phoenix.HTML

        def my_component(name, assigns \\ []), do: render(name, Enum.into(assigns, %{}))

        unquote_splicing(render_functions)
      end
    end
  end

  defp render_component(%Component{site: site, name: name, body: body}) do
    file = "site-#{site}-component-#{name}"
    ast = Beacon.Loader.compile_template!(site, file, body)

    quote do
      def render(unquote(name), var!(assigns)) when is_map(var!(assigns)) do
        unquote(ast)
      end
    end
  end
end
