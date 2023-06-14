defmodule Beacon.Loader.ComponentModuleLoader do
  @moduledoc false

  require Logger

  alias Beacon.Loader

  def load_components(_site, [] = _components) do
    :skip
  end

  def load_components(site, components) do
    component_module = Loader.component_module_for_site(site)
    render_functions = Enum.map(components, &render_component/1)
    ast = render(component_module, render_functions)
    :ok = Loader.reload_module!(component_module, ast)
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

  defp render_component(%Beacon.Components.Component{site: site, name: name, body: body}) do
    file = "site-#{site}-component-#{name}"
    ast = Beacon.Template.HEEx.compile_heex_template!(file, body)

    quote do
      def render(unquote(name), var!(assigns)) when is_map(var!(assigns)) do
        unquote(ast)
      end
    end
  end
end
