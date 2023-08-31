defmodule Beacon.Loader.ErrorModuleLoader do
  @moduledoc false
  alias Beacon.Content
  alias Beacon.Content.ErrorPage
  alias Beacon.Loader

  def load_error_pages!(error_pages, site) do
    error_module = Loader.error_module_for_site(site)
    component_module = Loader.component_module_for_site(site)
    layout_functions = Enum.map(error_pages, &build_layout_fn/1)
    render_functions = Enum.map(error_pages, &build_render_fn(&1, error_module))

    ast =
      quote do
        defmodule unquote(error_module) do
          use Phoenix.HTML
          require EEx
          import Phoenix.Component
          unquote(Loader.maybe_import_my_component(component_module, render_functions ++ layout_functions))
          require Logger

          # One function per error page
          unquote_splicing(layout_functions)

          # One function per error page
          unquote_splicing(render_functions)

          # Catch-all for error which do not have an ErrorPage defined
          def render(var!(status)) do
            Logger.warning("Missing Error page for #{unquote(site)} status #{var!(status)}")
            Plug.Conn.Status.reason_phrase(var!(status))
          end

          EEx.function_from_file(
            :def,
            :root_layout,
            Path.join([:code.priv_dir(:beacon), "layouts", "runtime_error.html.heex"]),
            [:assigns]
          )
        end
      end

    :ok = Loader.reload_module!(error_module, ast)

    {:ok, error_module, ast}
  end

  defp build_layout_fn(%ErrorPage{} = error_page) do
    %{site: site, layout: %{id: layout_id}, status: status} = error_page
    %{template: template} = Content.get_published_layout(site, layout_id)

    compiled = EEx.compile_string(template)

    quote do
      def layout(unquote(status), var!(assigns)) when is_map(var!(assigns)) do
        unquote(compiled)
      end
    end
  end

  defp build_render_fn(%ErrorPage{} = error_page, error_module) do
    %{template: template, status: status} = error_page

    quote do
      def render(var!(conn), unquote(status)) do
        var!(assigns) = %{conn: var!(conn), inner_content: unquote(error_module).layout(unquote(status), %{inner_content: unquote(template)})}
        unquote(error_module).root_layout(var!(assigns))
      end
    end
  end
end
