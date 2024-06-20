defmodule Beacon.Loader.Components do
  @moduledoc false

  # use the annotated def/defp macros from Declarative
  import Kernel, except: [def: 2, defp: 2]
  import Phoenix.Component.Declarative

  alias Beacon.Content
  alias Beacon.Loader

  @supported_attr_types ~w(any string atom boolean integer float list map global)

  def module_name(site), do: Loader.module_name(site, "Components")

  def build_ast(site, [] = _components) do
    routes_module = Loader.Routes.module_name(site)

    site
    |> module_name()
    |> render(routes_module)
  end

  def build_ast(site, components) do
    module = module_name(site)
    routes_module = Loader.Routes.module_name(site)
    render_functions = Enum.map(components, &render_component/1)
    function_components = Enum.map(components, &function_component/1)
    render(module, routes_module, render_functions, function_components)
  end

  # generate the module even without functions because it gets
  # imported into other modules
  defp render(component_module, routes_module) do
    quote do
      defmodule unquote(component_module) do
        use PhoenixHTMLHelpers
        import Phoenix.HTML
        import Phoenix.HTML.Form
        import Phoenix.Component, except: [assign: 2, assign: 3, assign_new: 3]
        import BeaconWeb, only: [assign: 2, assign: 3, assign_new: 3]
        import Beacon.Router, only: [beacon_asset_path: 2, beacon_asset_url: 2]
        import unquote(routes_module)

        # TODO: remove my_component/2
        def my_component(name, assigns \\ []) do
          Beacon.apply_mfa(__MODULE__, :render, [name, Enum.into(assigns, %{})])
        end
      end
    end
  end

  defp render(component_module, routes_module, render_functions, function_components) do
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
        import Phoenix.Component, except: [assign: 2, assign: 3, assign_new: 3]
        import BeaconWeb, only: [assign: 2, assign: 3, assign_new: 3]
        import Beacon.Router, only: [beacon_asset_path: 2, beacon_asset_url: 2]
        import unquote(routes_module)

        # TODO: remove my_component/2
        def my_component(name, assigns \\ []) do
          Beacon.apply_mfa(__MODULE__, :render, [name, Enum.into(assigns, %{})])
        end

        unquote_splicing(render_functions)
        unquote_splicing(function_components)
      end
    end
  end

  defp function_component(%Content.Component{} = component) do
    Beacon.safe_code_check!(component.site, component.body)

    quote do
      unquote_splicing(
        for component_attr <- component.attrs do
          quote do
            attr.(unquote(String.to_atom(component_attr.name)), unquote(att_type_to_atom(component_attr.type)), unquote(component_attr.opts))
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
                      attr.(unquote(String.to_atom(slot_attr.name)), unquote(att_type_to_atom(slot_attr.type)), unquote(slot_attr.opts))
                    end
                  end
                )
            )
          end
        end
      )

      def unquote(String.to_atom(component.name))(var!(assigns)) do
        unquote(Code.string_to_quoted!(component.body))
        unquote(compile_template!(component))
      end
    end
  end

  def att_type_to_atom(component_type) when component_type in @supported_attr_types do
    String.to_atom(component_type)
  end

  def att_type_to_atom(component_type) do
    Module.concat([component_type])
  end

  # TODO: remove render_component/1 along with my_component/2
  defp render_component(%Content.Component{} = component) do
    Beacon.safe_code_check!(component.site, component.body)

    quote do
      def render(unquote(component.name), var!(assigns)) when is_map(var!(assigns)) do
        unquote(Code.string_to_quoted!(component.body))
        unquote(compile_template!(component))
      end
    end
  end

  defp compile_template!(%Content.Component{site: site, name: name, template: template}) do
    file = "site-#{site}-component-#{name}"
    Beacon.Template.HEEx.compile!(site, "", template, file)
  end
end
