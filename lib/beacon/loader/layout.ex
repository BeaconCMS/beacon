defmodule Beacon.Loader.Layout do
  @moduledoc false

  alias Beacon.Loader

  def module_name(site, layout_id), do: Loader.module_name(site, "Layout#{layout_id}")

  def build_ast(site, layout) do
    module = module_name(site, layout.id)
    components_module = Loader.Components.module_name(site)
    render_function = render_layout(layout)
    render(module, components_module, render_function)
  end

  defp render(module_name, components_module, render_function) do
    quote do
      defmodule unquote(module_name) do
        use PhoenixHTMLHelpers
        import Phoenix.HTML
        import Phoenix.HTML.Form
        import Phoenix.Component
        import unquote(components_module), only: [my_component: 2]

        unquote(render_function)
      end
    end
  end

  defp render_layout(layout) do
    file = "site-#{layout.site}-layout-#{layout.title}"
    {:ok, ast} = Beacon.Template.HEEx.compile(layout.site, "", layout.template, file)

    quote do
      def render(var!(assigns)) when is_map(var!(assigns)) do
        unquote(ast)
      end

      def layout_assigns do
        %{
          title: unquote(layout.title),
          meta_tags: unquote(Macro.escape(layout.meta_tags)),
          resource_links: unquote(Macro.escape(layout.resource_links))
        }
      end
    end
  end
end
