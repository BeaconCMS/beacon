defmodule BeaconWeb.Controllers.MediaLibraryControllerTest do
  use BeaconWeb.ConnCase, async: true

  import Beacon.Router, only: [beacon_asset_path: 2]

  test "show", %{conn: conn} do
    Beacon.Fixtures.media_library_asset_fixture()
    beacon = %{router: Beacon.BeaconTest.Router}
    path = beacon_asset_path(beacon, "image.jpg")

    conn = get(conn, path)

    assert response(conn, 200)
    assert response_content_type(conn, :jpg) =~ "charset=utf-8"
  end
end
