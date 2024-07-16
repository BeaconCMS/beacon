defmodule Beacon.Loader.Layout do
  @moduledoc false

  alias Beacon.Loader

  def module_name(site, layout_id), do: Loader.module_name(site, "Layout#{layout_id}")

  def build_ast(site, layout) do
    module = module_name(site, layout.id)
    routes_module = Loader.Routes.module_name(site)
    components_module = Loader.Components.module_name(site)
    render_function = render_layout(layout)
    render(module, routes_module, components_module, render_function)
  end

  defp render(module_name, routes_module, components_module, render_function) do
    quote do
      defmodule unquote(module_name) do
        import Phoenix.HTML
        import Phoenix.HTML.Form
        import PhoenixHTMLHelpers.Form, except: [label: 1]
        import PhoenixHTMLHelpers.Link
        import PhoenixHTMLHelpers.Tag
        import PhoenixHTMLHelpers.Format
        import Phoenix.Component, except: [assign: 2, assign: 3, assign_new: 3]
        import BeaconWeb, only: [assign: 2, assign: 3, assign_new: 3]
        import Beacon.Router, only: [beacon_asset_path: 2, beacon_asset_url: 2]
        import unquote(routes_module)
        import unquote(components_module)

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
