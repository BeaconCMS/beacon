defmodule BeaconWeb.Live.Admin.MediaLibraryLive.IndexTest do
  use BeaconWeb.ConnCase, async: true
  import Beacon.Fixtures
  alias Beacon.Admin.MediaLibrary

  test "index", %{conn: conn} do
    media_library_asset_fixture(file_name: "test_index.webp")

    {:ok, _view, html} = live(conn, "/admin/media_library")

    assert html =~ "test_index.webp"
  end

  test "soft delete", %{conn: conn} do
    asset = media_library_asset_fixture(file_name: "test_delete.webp")

    {:ok, view, _html} = live(conn, "/admin/media_library")

    html =
      view
      |> element("tr##{asset.id} a", "Delete")
      |> render_click()

    refute html =~ "test_delete.webp"

    deleted_asset = MediaLibrary.get_asset!(asset.id)
    assert deleted_asset.deleted_at
  end

  test "search", %{conn: conn} do
    media_library_asset_fixture(file_name: "test_search.webp")

    {:ok, view, _html} = live(conn, "/admin/media_library")

    assert view
           |> element("#search-form")
           |> render_change(%{search: "ar"}) =~ "test_search.webp"
  end
end
