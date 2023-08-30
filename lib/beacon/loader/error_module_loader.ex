defmodule Beacon.Loader.ErrorModuleLoader do
  @moduledoc false
  alias Beacon.Content
  alias Beacon.Loader

  @root_layout """
  <!DOCTYPE html>
  <html lang="en">
    <head>
      <meta name="csrf-token" content={get_csrf_token()} />
      <.live_title>
        Error
      </.live_title>
      <link id="beacon-runtime-stylesheet" rel="stylesheet" href={asset_path(@conn, :css)} />
      <script defer src={asset_path(@conn, :js)}>
      </script>
    </head>
    <body>
      <%= @inner_content %>
    </body>
  </html>
  """

  def load_error_pages!(error_pages, site) do
    error_module = Loader.error_module_for_site(site)
    component_module = Loader.component_module_for_site(site)

    render_functions = Enum.map(error_pages, &build_render_fn/1)
    layout_functions = Enum.map(error_pages, &build_layout_fn/1)

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
            Logger.warning("Missing Error page for #{unquote(site)} status #{var!(status)}")
            Plug.Conn.Status.reason_phrase(var!(status))
          end

          # One function per error page
          unquote_splicing(layout_functions)
        end
      end

    :ok = Loader.reload_module!(error_module, ast)

    {:ok, error_module, ast}
  end

  defp build_layout_fn(error_page) do
    %{site: site, template: page_template, layout: %{id: layout_id}, status: status} = error_page
    layout = Content.get_published_layout(site, layout_id)

    file = "site-#{site}-error-page-#{status}"
    ast = Beacon.Template.HEEx.compile_heex_template!(file, page_template)

    layout_module = Loader.layout_module_for_site(layout.id)

    rendered_layout =
      layout_module.render(%{
        inner_content: ast,
        beacon_live_data: %{},
        title: layout.title,
        meta_tags: layout.meta_tags,
        resource_links: layout.resource_links
      })

    ast = EEx.compile_string(@root_layout, inner_content: rendered_layout)

    quote do
      def layout(unquote(status), var!(assigns)) do
        unquote(ast)
      end
    end
  end

  defp build_render_fn(error_page) do
    %{site: site, template: page_template, status: status} = error_page

    error_module = Loader.error_module_for_site(site)
    file = "site-#{site}-error-page-#{status}"
    ast = Beacon.Template.HEEx.compile_heex_template!(file, page_template)

    quote do
      def render(unquote(error_page.status)) do
        var!(assigns) = %{}
        apply(unquote(error_module), :layout, [unquote(status), %{inner_content: unquote(ast)}])
      end
    end
  end
end
