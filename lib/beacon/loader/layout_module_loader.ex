defmodule Beacon.Loader.LayoutModuleLoader do
  @moduledoc false

  require Logger

  alias Beacon.Layouts.Layout

  def load_layout!(site, layout) do
    component_module = Beacon.Loader.component_module_for_site(site)
    module = Beacon.Loader.layout_module_for_site(site, layout.id)
    render_function = render_layout(layout)
    ast = render(module, render_function, component_module)
    :ok = Beacon.Loader.reload_module!(module, ast)
    {:ok, ast}
  end

  defp render(module_name, render_function, component_module) do
    quote do
      defmodule unquote(module_name) do
        use Phoenix.HTML
        import Phoenix.Component
        unquote(Beacon.Loader.maybe_import_my_component(component_module, render_function))

        unquote(render_function)
      end
    end
  end

  defp render_layout(%Layout{} = layout) do
    file = "site-#{layout.site}-layout-#{layout.title}"
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
