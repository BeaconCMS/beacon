defmodule BeaconWeb.Controllers.MediaLibraryControllerTest do
  use BeaconWeb.ConnCase, async: true

  test "show", %{conn: conn} do
    Beacon.Fixtures.media_library_asset_fixture()
    attrs = %Beacon.BeaconAttrs{site: :my_site, prefix: ""}
    path = Beacon.Router.beacon_asset_path(attrs, "image.jpg")

    conn = get(conn, path)

    assert response(conn, 200)
    assert response_content_type(conn, :jpg) =~ "charset=utf-8"
  end
end
