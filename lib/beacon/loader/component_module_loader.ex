defmodule Beacon.Loader.ComponentModuleLoader do
  @moduledoc false

  # use the annotated def/defp macros from Declarative
  import Kernel, except: [def: 2, defp: 2]
  import Phoenix.Component.Declarative

  alias Beacon.Content
  alias Beacon.Loader

  # TODO: remove this guard, it should generate an empty module
  def load_components(_site, [] = _components) do
    :skip
  end

  def load_components(site, components) do
    component_module = Loader.component_module_for_site(site)
    render_functions = Enum.map(components, &render_component/1)
    function_components = Enum.map(components, &function_component/1)
    ast = render(component_module, render_functions, function_components)
    :ok = Loader.reload_module!(component_module, ast)
    {:ok, component_module}
  end

  defp render(component_module, render_functions, function_components) do
    quote do
      defmodule unquote(component_module) do
        import Phoenix.Component.Declarative

        [] = Phoenix.Component.Declarative.__setup__(__MODULE__, [])

        attr = fn name, type, opts ->
          Phoenix.Component.Declarative.__attr__!(__MODULE__, name, type, opts, __ENV__.line, __ENV__.file)
        end

        slot = fn name, opts ->
          Phoenix.Component.Declarative.__slot__!(__MODULE__, name, opts, __ENV__.line, __ENV__.file, fn -> nil end)
        end

        use PhoenixHTMLHelpers
        import Phoenix.HTML
        import Phoenix.HTML.Form
        import Phoenix.Component

        # TODO: remove my_component/2
        def my_component(name, assigns \\ []), do: render(name, Enum.into(assigns, %{}))

        unquote_splicing(render_functions)
        unquote_splicing(function_components)
      end
    end
  end

  defp function_component(%Content.Component{site: site, name: name, body: body} = component) do
    quote do
      unquote_splicing(
        for component_attr <- component.attrs do
          quote do
            attr.(unquote(String.to_atom(component_attr.name)), unquote(String.to_atom(component_attr.type)), doc: "hello")
          end
        end
      )

      def unquote(String.to_atom(name))(var!(assigns)) do
        unquote(compile_body(component))
      end
    end
  end

  defp compile_body(%Content.Component{site: site, name: name, body: body}) do
    file = "site-#{site}-component-#{name}"
    {:ok, ast} = Beacon.Template.HEEx.compile(site, "", body, file)
    ast
  end

  # TODO: remove render_component/1 along with my_component/2
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
