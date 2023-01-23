defmodule BeaconWeb.Live.Admin.MediaLibraryLive.IndexTest do
  use BeaconWeb.ConnCase, async: true
  import Beacon.Fixtures

  test "index", %{conn: conn} do
    media_library_asset_fixture(file_name: "test_index.jpg")

    {:ok, _view, html} = live(conn, "/admin/media_library")

    assert html =~ "test_index.jpg"
  end

  test "search", %{conn: conn} do
    media_library_asset_fixture(file_name: "test_search.jpg")

    {:ok, view, _html} = live(conn, "/admin/media_library")

    assert view
           |> element("#search-form")
           |> render_change(%{search: "ar"}) =~ "test_search.jpg"
  end
end
