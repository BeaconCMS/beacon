defmodule Beacon.Loader.LayoutModuleLoader do
  require Logger

  alias Beacon.Layouts.Layout
  alias Beacon.Loader.ModuleLoader

  def load_layouts(site, layouts) do
    component_module = Beacon.Loader.component_module_for_site(site)
    module = Beacon.Loader.layout_module_for_site(site)
    render_functions = Enum.map(layouts, &render_layout/1)
    ast = render(module, render_functions, component_module)
    :ok = ModuleLoader.load(module, ast)
    {:ok, ast}
  end

  defp render(module_name, render_functions, component_module) do
    quote do
      defmodule unquote(module_name) do
        use Phoenix.HTML
        import Phoenix.Component
        unquote(ModuleLoader.maybe_import_my_component(component_module, render_functions))

        unquote_splicing(render_functions)
      end
    end
  end

  defp render_layout(%Layout{} = layout) do
    file = "layout-render-#{layout.title}"
    ast = Beacon.Loader.compile_template!(layout.site, file, layout.body)

    quote do
      def render(unquote(layout.id), var!(assigns)) when is_map(var!(assigns)) do
        unquote(ast)
      end

      def layout_assigns(unquote(layout.id)) do
        %{
          title: unquote(layout.title),
          meta_tags: unquote(Macro.escape(layout.meta_tags)),
          stylesheet_urls: unquote(layout.stylesheet_urls)
        }
      end
    end
  end
end
