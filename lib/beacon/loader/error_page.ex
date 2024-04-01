defmodule Beacon.Loader.ErrorPage do
  @moduledoc false

  alias Beacon.Loader

  def module_name(site), do: Loader.module_name(site, "ErrorPage")

  def build_ast(site, error_pages) do
    module = module_name(site)
    layout_functions = Enum.map(error_pages, &build_layout_fn/1)
    render_functions = Enum.map(error_pages, &build_render_fn(&1, module))

    quote do
      defmodule unquote(module) do
        require Logger
        require EEx
        use PhoenixHTMLHelpers
        import Phoenix.HTML
        import Phoenix.HTML.Form
        import Phoenix.Component

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

  defp build_render_fn(error_page, error_module) do
    %{template: template, status: status} = error_page
    compiled = EEx.compile_string(template, engine: Phoenix.HTML.Engine)

    quote do
      def render(var!(conn), unquote(status)) do
        var!(assigns) = %{conn: var!(conn), inner_content: unquote(error_module).layout(unquote(status), %{inner_content: unquote(compiled)})}
        unquote(error_module).root_layout(var!(assigns))
      end
    end
  end
end
