defmodule BeaconWeb.Controllers.MediaLibraryControllerTest do
  use BeaconWeb.ConnCase, async: true

  test "show", %{conn: conn} do
    %{file_name: file_name} = Beacon.Fixtures.media_library_asset_fixture()
    path = Beacon.Router.beacon_asset_path(:my_site, file_name)

    conn = get(conn, path)

    assert response(conn, 200)
    assert response_content_type(conn, :webp) =~ "charset=utf-8"
  end
end
