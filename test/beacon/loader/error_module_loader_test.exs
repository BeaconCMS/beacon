defmodule Beacon.Loader.ErrorModuleLoaderTest do
  use BeaconWeb.ConnCase, async: false
  import Beacon.Fixtures
  alias Beacon.Loader.ErrorModuleLoader

  @site :my_site

  defp load_error_pages_module(site) do
    {:ok, module, _ast} =
      site
      |> Beacon.Content.list_error_pages()
      |> Beacon.Repo.preload(:layout)
      |> ErrorModuleLoader.load_error_pages!(site)

    module
  end

  def build_conn(conn) do
    conn
    |> Plug.Conn.assign(:__site__, @site)
    |> Plug.Conn.put_private(:phoenix_router, Beacon.BeaconTest.Router)
  end

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(@site)})
    :ok
  end

  setup %{conn: conn} do
    :ok = Beacon.Loader.populate_layouts(@site)
    :ok = Beacon.Loader.populate_error_pages(@site)
    error_module = load_error_pages_module(@site)

    [conn: build_conn(conn), error_module: error_module]
  end

  test "root layout", %{conn: conn, error_module: error_module} do
    layout_template = "#inner_content#"
    csrf_token = Phoenix.Controller.get_csrf_token()

    assert error_module.root_layout(%{conn: conn, inner_content: layout_template}) == """
           <!DOCTYPE html>
           <html lang="en">
             <head>
               <meta name="csrf-token" content=#{csrf_token} />
               <title>Error</title>
               <link id="beacon-runtime-stylesheet" rel="stylesheet" href=/beacon_assets/css- />
               <script defer src=/beacon_assets/js->
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

  test "default error pages", %{conn: conn, error_module: error_module} do
    csrf_token = Phoenix.Controller.get_csrf_token()

    assert error_module.render(conn, 404) == """
           <!DOCTYPE html>
           <html lang="en">
             <head>
               <meta name="csrf-token" content=#{csrf_token} />
               <title>Error</title>
               <link id="beacon-runtime-stylesheet" rel="stylesheet" href=/beacon_assets/css- />
               <script defer src=/beacon_assets/js->
               </script>
             </head>
             <body>
               Not Found
             </body>
           </html>
           """

    assert error_module.render(conn, 500) == """
           <!DOCTYPE html>
           <html lang="en">
             <head>
               <meta name="csrf-token" content=#{csrf_token} />
               <title>Error</title>
               <link id="beacon-runtime-stylesheet" rel="stylesheet" href=/beacon_assets/css- />
               <script defer src=/beacon_assets/js->
               </script>
             </head>
             <body>
               Internal Server Error
             </body>
           </html>
           """
  end

  test "custom error page", %{conn: conn} do
    layout = published_layout_fixture(template: "#custom_layout#<%= @inner_content %>", site: @site)
    _error_page = error_page_fixture(layout: layout, template: "error_501", status: 501, site: @site)
    error_module = load_error_pages_module(@site)
    csrf_token = Phoenix.Controller.get_csrf_token()

    assert error_module.render(conn, 501) == """
           <!DOCTYPE html>
           <html lang="en">
             <head>
               <meta name="csrf-token" content=#{csrf_token} />
               <title>Error</title>
               <link id="beacon-runtime-stylesheet" rel="stylesheet" href=/beacon_assets/css- />
               <script defer src=/beacon_assets/js->
               </script>
             </head>
             <body>
               #custom_layout#error_501
             </body>
           </html>
           """
  end
end
