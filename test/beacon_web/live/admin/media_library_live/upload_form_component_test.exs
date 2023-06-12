defmodule BeaconWeb.Live.Admin.MediaLibraryLive.UploadFormComponentTest do
  use BeaconWeb.ConnCase, async: true
  alias Beacon.Admin.MediaLibrary

  import Beacon.Support.BypassHelpers

  describe "uploads" do
    setup [:start_bypass]

    test "upload valid files", %{conn: conn, bypass: bypass} do
      setup_multipart_upload_backend(bypass, self(), "s3_site/image.webp")
      {:ok, view, _html} = live(conn, "/admin/media_library/upload")

      assert has_element?(view, "h1", "Upload")

      view
      |> element("#site-input")
      |> render_change(%{site: "s3_site"})

      asset =
        file_input(view, "#asset-form", :asset, [
          %{
            last_modified: 1_594_171_879_000,
            name: "image.jpg",
            content: File.read!("test/support/fixtures/image.jpg"),
            type: "image/jpeg"
          }
        ])

      assert render_upload(asset, "image.jpg") =~ "image.webp"

      # site :lifecycle_test is configured to create a copy of uploaded assets
      # see test/test_helper.exs
      assets = MediaLibrary.list_assets()
      assert Enum.any?(assets, fn asset -> asset.file_name == "image.webp" end)
    end
  end
end
