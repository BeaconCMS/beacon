defmodule Beacon.Loader.ComponentModuleLoader do
  @moduledoc false

  # use the annotated def/defp macros from Declarative
  import Kernel, except: [def: 2, defp: 2]
  import Phoenix.Component.Declarative

  alias Beacon.Content
  alias Beacon.Loader

  @supported_component_types [:any, :atom, :boolean, :float, :global, :integer, :list, :map, :string]

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

        slot = fn name, opts, block ->
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

  defp function_component(%Content.Component{name: name} = component) do
    quote do
      unquote_splicing(
        for component_attr <- component.attrs do
          quote do
            attr.(unquote(String.to_atom(component_attr.name)), unquote(convert_component_type(component_attr.type)), unquote(component_attr.opts))
          end
        end
      )

      unquote_splicing(
        for component_slot <- component.slots do
          quote do
            slot.(unquote(String.to_atom(component_slot.name)), unquote(component_slot.opts),
              do:
                unquote_splicing(
                  for slot_attr <- component_slot.attrs do
                    quote do
                      attr.(unquote(String.to_atom(slot_attr.name)), unquote(convert_component_type(slot_attr.type)), unquote(slot_attr.opts))
                    end
                  end
                )
            )
          end
        end
      )

      def unquote(String.to_atom(name))(var!(assigns)) do
        unquote(compile_body(component))
      end
    end
  end

  def convert_component_type(component_type) do
    component_type
    |> String.to_atom()
    |> maybe_convert_to_struct_type()
  end

  def maybe_convert_to_struct_type(component_type) when component_type in @supported_component_types, do: component_type
  def maybe_convert_to_struct_type(component_type), do: Module.concat([component_type])

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
