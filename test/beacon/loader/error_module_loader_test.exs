defmodule Beacon.Loader.ErrorModuleLoaderTest do
  use BeaconWeb.ConnCase, async: false
  import Beacon.Fixtures
  alias Beacon.Loader.ErrorModuleLoader

  @site :my_site

  defp load_error_pages_module(site) do
    {:ok, module, _ast} =
      site
      |> Beacon.Content.list_error_pages(preloads: [:layout])
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
    expected =
      ~S"""
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta name="csrf-token" content=.* />
          <title>Error</title>
          <link rel="stylesheet" href=/beacon_assets/css.* />
          <script defer src=/beacon_assets/js.*>
          </script>
        </head>
        <body>
          #inner_content#
        </body>
      </html>
      """
      |> Regex.compile!()

    {:safe, html} = error_module.root_layout(%{conn: conn, inner_content: "#inner_content#"})
    assert IO.iodata_to_binary(html) =~ expected
  end

  test "default layouts", %{error_module: error_module} do
    assert error_module.layout(404, %{inner_content: "Not Found"}) == {:safe, ["Not Found"]}
    assert error_module.layout(500, %{inner_content: "Internal Server Error"}) == {:safe, ["Internal Server Error"]}
  end

  test "custom layout" do
    layout = published_layout_fixture(template: "#custom_layout#<%= @inner_content %>", site: @site)
    error_page = error_page_fixture(layout: layout, template: "error_501", status: 501, site: @site)
    error_module = load_error_pages_module(@site)

    assert error_module.layout(501, %{inner_content: error_page.template}) == {:safe, ["#custom_layout#", "error_501"]}
  end

  test "default error pages", %{conn: conn, error_module: error_module} do
    expected =
      ~S"""
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta name="csrf-token" content=.* />
          <title>Error</title>
          <link rel="stylesheet" href=/beacon_assets/css.* />
          <script defer src=/beacon_assets/js.*>
          </script>
        </head>
        <body>
          Not Found
        </body>
      </html>
      """
      |> Regex.compile!()

    {:safe, html} = error_module.render(conn, 404)
    assert IO.iodata_to_binary(html) =~ expected

    expected =
      ~S"""
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta name="csrf-token" content=.* />
          <title>Error</title>
          <link rel="stylesheet" href=/beacon_assets/css.* />
          <script defer src=/beacon_assets/js.*>
          </script>
        </head>
        <body>
          Internal Server Error
        </body>
      </html>
      """
      |> Regex.compile!()

    {:safe, html} = error_module.render(conn, 500)
    assert IO.iodata_to_binary(html) =~ expected
  end

  test "custom error page", %{conn: conn} do
    layout = published_layout_fixture(template: "#custom_layout#<%= @inner_content %>", site: @site)
    _error_page = error_page_fixture(layout: layout, template: "error_501", status: 501, site: @site)
    error_module = load_error_pages_module(@site)

    expected =
      ~S"""
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta name="csrf-token" content=.* />
          <title>Error</title>
          <link rel="stylesheet" href=/beacon_assets/css.* />
          <script defer src=/beacon_assets/js.*>
          </script>
        </head>
        <body>
          #custom_layout#error_501
        </body>
      </html>
      """
      |> Regex.compile!()

    {:safe, html} = error_module.render(conn, 501)
    assert IO.iodata_to_binary(html) =~ expected
  end
end
