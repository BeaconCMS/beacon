defmodule Beacon.Web.Controllers.MediaLibraryControllerTest do
  use Beacon.Web.ConnCase, async: true

  test "show returns error when asset has no file_body", %{conn: conn} do
    %{file_name: file_name} = Beacon.Test.Fixtures.beacon_media_library_asset_fixture(site: :my_site)
    routes = Beacon.Loader.fetch_routes_module(:my_site)
    path = Beacon.apply_mfa(:my_site, routes, :beacon_media_path, [file_name])

    assert_raise Beacon.Web.NotFoundError, ~r/no file_body/, fn ->
      get(conn, path)
    end
  end
end
