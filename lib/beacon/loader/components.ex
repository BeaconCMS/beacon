defmodule Beacon.Loader.Components do
  @moduledoc false

  alias Beacon.Content
  alias Beacon.Loader

  def module_name(site), do: Loader.module_name(site, "Components")

  def build_ast(site, [] = _components) do
    site
    |> module_name()
    |> render()
  end

  def build_ast(site, components) do
    module = module_name(site)
    render_functions = Enum.map(components, &render_component/1)
    render(module, render_functions)
  end

  # generate the module even without functions because it gets
  # imported into other modules
  defp render(component_module) do
    quote do
      defmodule unquote(component_module) do
        use PhoenixHTMLHelpers
        import Phoenix.HTML
        import Phoenix.HTML.Form
        import Phoenix.Component

        def my_component(name, assigns \\ []) do
          Beacon.apply_mfa(__MODULE__, :render, [name, Enum.into(assigns, %{})])
        end
      end
    end
  end

  defp render(component_module, render_functions) do
    quote do
      defmodule unquote(component_module) do
        use PhoenixHTMLHelpers
        import Phoenix.HTML
        import Phoenix.HTML.Form
        import Phoenix.Component

        def my_component(name, assigns \\ []) do
          Beacon.apply_mfa(__MODULE__, :render, [name, Enum.into(assigns, %{})])
        end

        unquote_splicing(render_functions)
      end
    end
  end

  defp render_component(%Content.Component{site: site, name: name, body: body}) do
    quote do
      def render(unquote(name), var!(assigns)) when is_map(var!(assigns)) do
        unquote(Beacon.Template.HEEx.compile!(site, "", body, "site-#{site}-component-#{name}"))
      end
    end
  end
end
