defmodule Beacon.Loader.ErrorPage do
  @moduledoc false

  alias Beacon.Loader

  def module_name(site), do: Loader.module_name(site, "ErrorPage")

  def build_ast(site, error_pages) do
    module = module_name(site)
    routes_module = Loader.Routes.module_name(site)
    layout_functions = Enum.map(error_pages, &build_layout_fn/1)
    render_functions = Enum.map(error_pages, &build_render_fn/1)

    # `import` modules won't be autoloaded
    Loader.ensure_loaded!([routes_module], site)

    quote do
      defmodule unquote(module) do
        require Logger
        require EEx
        import Phoenix.HTML
        import Phoenix.HTML.Form
        import PhoenixHTMLHelpers.Form, except: [label: 1]
        import PhoenixHTMLHelpers.Link
        import PhoenixHTMLHelpers.Tag
        import PhoenixHTMLHelpers.Format
        import Phoenix.Component, except: [assign: 2, assign: 3, assign_new: 3]
        import Beacon.Web, only: [assign: 2, assign: 3, assign_new: 3]
        import Beacon.Router, only: [beacon_asset_path: 2, beacon_asset_url: 2]
        import unquote(routes_module)

        unquote_splicing(layout_functions)
        unquote_splicing(render_functions)

        # catch-all for error which do not have an ErrorPage defined
        def render(var!(conn), var!(status)) do
          _ = var!(conn)
          Logger.warning("missing error page for #{unquote(site)} status #{var!(status)}")
          Plug.Conn.Status.reason_phrase(var!(status))
        end

        EEx.function_from_file(
          :def,
          :root_layout,
          Path.join([:code.priv_dir(:beacon), "layouts", "runtime_error.html.heex"]),
          [:assigns],
          engine: Phoenix.HTML.Engine
        )
      end
    end
  end

  defp build_layout_fn(error_page) do
    %{layout: %{template: template}, status: status} = error_page
    compiled = EEx.compile_string(template, engine: Phoenix.HTML.Engine)

    quote do
      def layout(unquote(status), var!(assigns)) when is_map(var!(assigns)) do
        unquote(compiled)
      end
    end
  end

  defp build_render_fn(error_page) do
    %{template: template, status: status} = error_page
    compiled = EEx.compile_string(template, engine: Phoenix.HTML.Engine)

    quote do
      def render(var!(conn), unquote(status)) do
        var!(assigns) = %{conn: var!(conn), inner_content: layout(unquote(status), %{inner_content: unquote(compiled)})}
        root_layout(var!(assigns))
      end
    end
  end
end
