defmodule Beacon.Loader.ErrorModuleLoader do
  @moduledoc false
  alias Beacon.Loader

  def load_error_pages!(error_pages, site) do
    error_module = Loader.error_module_for_site(site)
    component_module = Loader.component_module_for_site(site)

    render_functions = Enum.map(error_pages, &build_render_fn/1)

    ast =
      quote do
        defmodule unquote(error_module) do
          use Phoenix.HTML
          import Phoenix.Component
          unquote(Loader.maybe_import_my_component(component_module, render_functions))
          require Logger

          # One function per error page
          unquote_splicing(render_functions)

          # Catch-all for error which do not have an ErrorPage defined
          def render(var!(status)) do
            Logger.warn("Missing Error page for #{unquote(site)} status #{var!(status)}")
            Plug.Conn.Status.reason_phrase(var!(status))
          end
        end
      end

    :ok = Loader.reload_module!(error_module, ast)

    {:ok, error_module, ast}
  end

  defp build_render_fn(error_page) do
    %{site: site, template: page_template, layout: %{template: layout_template}} = error_page
    file = "site-#{site}-error-pages"

    quote do
      def render(unquote(error_page.status)) do
        content = Beacon.Template.HEEx.compile_heex_template!(unquote(file), unquote(page_template))
        Beacon.Template.HEEx.compile_heex_template!(unquote(file), unquote(layout_template), inner_content: content)
      end
    end
  end
end
