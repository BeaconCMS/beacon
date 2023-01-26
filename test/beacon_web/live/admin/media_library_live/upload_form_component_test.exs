defmodule BeaconWeb.Live.Admin.MediaLibraryLive.UploadFormComponentTest do
  use BeaconWeb.ConnCase, async: true
  alias Beacon.Admin.MediaLibrary

  test "upload valid files", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/admin/media_library/upload")

    assert has_element?(view, "h1", "Upload")

    asset =
      file_input(view, "#asset-form", :asset, [
        %{
          last_modified: 1_594_171_879_000,
          name: "image.jpg",
          content: File.read!("test/support/fixtures/image.jpg"),
          type: "image/jpg"
        }
      ])

    assert render_upload(asset, "image.jpg") =~ "image.jpg"

    assert [%{file_name: "image.jpg", file_type: "image/jpg"}] = MediaLibrary.list_assets()
  end
end
