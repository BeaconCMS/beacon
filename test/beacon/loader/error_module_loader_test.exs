defmodule Beacon.Loader.ErrorModuleLoaderTest do
  use Beacon.DataCase, async: false
  import Beacon.Fixtures
  alias Beacon.Loader.ErrorModuleLoader

  @site :my_site

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(@site)})
    :ok
  end

  setup do
    :ok = Beacon.Loader.populate_layouts(@site)
    :ok = Beacon.Loader.populate_error_pages(@site)
    error_module = load_error_pages_module(@site)
    [error_module: error_module]
  end

  test "root layout", %{error_module: error_module} do
    layout_template = "#inner_content#"

    assert error_module.root_layout(%{inner_content: layout_template}) == """
           <!DOCTYPE html>
           <html lang="en">
             <head>
               <meta name="csrf-token" content={get_csrf_token()} />
               <title>Error</title>
               <link id="beacon-runtime-stylesheet" rel="stylesheet" href={asset_path(@conn, :css)} />
               <script defer src={asset_path(@conn, :js)}>
               </script>
             </head>
             <body>
               #{layout_template}
             </body>
           </html>
           """
  end

  test "default layouts", %{error_module: error_module} do
    assert error_module.layout(404, %{inner_content: "Not Found"}) == "Not Found"
    assert error_module.layout(500, %{inner_content: "Internal Server Error"}) == "Internal Server Error"
  end

  test "custom layout" do
    layout = published_layout_fixture(template: "#custom_layout#<%= @inner_content %>", site: @site)
    error_page = error_page_fixture(layout: layout, template: "error_501", status: 501, site: @site)
    error_module = load_error_pages_module(@site)
    assert error_module.layout(501, %{inner_content: error_page.template}) == "#custom_layout#error_501"
  end

  test "default error pages", %{error_module: error_module} do
    assert error_module.render(404) == """
           <!DOCTYPE html>
           <html lang="en">
             <head>
               <meta name="csrf-token" content={get_csrf_token()} />
               <title>Error</title>
               <link id="beacon-runtime-stylesheet" rel="stylesheet" href={asset_path(@conn, :css)} />
               <script defer src={asset_path(@conn, :js)}>
               </script>
             </head>
             <body>
               Not Found
             </body>
           </html>
           """

    assert error_module.render(500) == """
           <!DOCTYPE html>
           <html lang="en">
             <head>
               <meta name="csrf-token" content={get_csrf_token()} />
               <title>Error</title>
               <link id="beacon-runtime-stylesheet" rel="stylesheet" href={asset_path(@conn, :css)} />
               <script defer src={asset_path(@conn, :js)}>
               </script>
             </head>
             <body>
               Internal Server Error
             </body>
           </html>
           """
  end

  test "custom error page" do
    layout = published_layout_fixture(template: "#custom_layout#<%= @inner_content %>", site: @site)
    _error_page = error_page_fixture(layout: layout, template: "error_501", status: 501, site: @site)
    error_module = load_error_pages_module(@site)

    assert error_module.render(501) == """
           <!DOCTYPE html>
           <html lang="en">
             <head>
               <meta name="csrf-token" content={get_csrf_token()} />
               <title>Error</title>
               <link id="beacon-runtime-stylesheet" rel="stylesheet" href={asset_path(@conn, :css)} />
               <script defer src={asset_path(@conn, :js)}>
               </script>
             </head>
             <body>
               #custom_layout#error_501
             </body>
           </html>
           """
  end

  defp load_error_pages_module(site) do
    {:ok, module, _ast} =
      site
      |> Beacon.Content.list_error_pages()
      |> Beacon.Repo.preload(:layout)
      |> ErrorModuleLoader.load_error_pages!(site)

    module
  end
end
