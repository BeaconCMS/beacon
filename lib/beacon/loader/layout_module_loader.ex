defmodule Beacon.Loader.LayoutModuleLoader do
  @moduledoc false

  require Logger

  alias Beacon.Content
  alias Beacon.Loader

  def load_layout!(%Content.Layout{} = layout) do
    component_module = Loader.component_module_for_site(layout.site)
    module = Loader.layout_module_for_site(layout.site, layout.id)
    render_function = render_layout(layout)
    ast = render(module, render_function, component_module)
    :ok = Loader.reload_module!(module, ast)
    {:ok, ast}
  end

  defp render(module_name, render_function, component_module) do
    quote do
      defmodule unquote(module_name) do
        use Phoenix.HTML
        import Phoenix.Component
        unquote(Loader.maybe_import_my_component(component_module, render_function))

        unquote(render_function)
      end
    end
  end

  defp render_layout(layout) do
    file = "site-#{layout.site}-layout-#{layout.title}"
    ast = Beacon.Template.HEEx.compile_heex_template!(file, layout.body)

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
