defmodule Beacon.Loader.ComponentModuleLoader do
  @moduledoc false

  require Logger

  alias Beacon.Content
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

        def my_component(name, assigns \\ []), do: render(name, Enum.into(assigns, %{}))

        unquote_splicing(render_functions)
      end
    end
  end

  defp render_component(%Content.Component{site: site, name: name, body: body}) do
    file = "site-#{site}-component-#{name}"
    {:ok, ast} = Beacon.Template.HEEx.compile(site, "", body, file)

    quote do
      def render(unquote(name), var!(assigns)) when is_map(var!(assigns)) do
        unquote(ast)
      end
    end
  end
end
