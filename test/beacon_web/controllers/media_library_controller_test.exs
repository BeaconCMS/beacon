defmodule Beacon.Web.Controllers.MediaLibraryControllerTest do
  use Beacon.Web.ConnCase, async: true

  test "show", %{conn: conn} do
    %{file_name: file_name} = Beacon.Fixtures.media_library_asset_fixture(site: :my_site)
    routes = Beacon.Loader.fetch_routes_module(:my_site)
    path = Beacon.apply_mfa(routes, :beacon_asset_path, [file_name])

    conn = get(conn, path)

    assert response(conn, 200)
    assert response_content_type(conn, :webp) =~ "charset=utf-8"
  end
end
