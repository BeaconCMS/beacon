defmodule Beacon.MediaLibraryTest do
  use Beacon.DataCase, async: true
  use Beacon.Test, site: :my_site

  alias Beacon.MediaLibrary
  alias Beacon.MediaLibrary.Asset

  import Beacon.Support.BypassHelpers

  test "search by file name" do
    beacon_media_library_asset_fixture(file_name: "my_file.webp")
    beacon_media_library_asset_fixture(file_name: "other_file.webp")

    hits = MediaLibrary.search(default_site(), "my")

    assert Enum.all?(hits, fn asset -> String.contains?(asset.file_name, "my") end)
  end

  test "soft delete" do
    asset = beacon_media_library_asset_fixture(file_name: "my_file.png")

    assert {:ok, %Asset{deleted_at: deleted_at, updated_at: updated_at}} = MediaLibrary.soft_delete(asset)
    assert deleted_at
    assert updated_at == asset.updated_at
  end

  describe "uploads" do
    setup [:start_bypass]

    test "upload asset, converts to webp by default, s3 store", %{bypass: bypass} do
      setup_multipart_upload_provider(bypass, self(), "s3_site/image.webp")

      metadata = beacon_upload_metadata_fixture(file_name: "image.png", site: :s3_site)
      assert %Asset{file_name: "image.webp", media_type: "image/webp"} = asset = MediaLibrary.upload(metadata)
      assert "http://beacon-media-library.localhost/s3_site/image.webp" = MediaLibrary.url_for(asset)
    end

    test "upload asset, converts to webp by default, repo store" do
      Process.flag(:error_handler, Beacon.ErrorHandler)
      Process.put(:__beacon_site__, :my_site)

      metadata = beacon_upload_metadata_fixture(file_name: "image.png")
      assert %Asset{file_name: "image.webp", media_type: "image/webp"} = asset = MediaLibrary.upload(metadata)
      assert "http://site_a.com/__beacon_media__/image.webp" = MediaLibrary.url_for(asset)
    end
  end

  describe "list_assets" do
    test "page and per_page" do
      beacon_media_library_asset_fixture(file_name: "image_a.png")
      beacon_media_library_asset_fixture(file_name: "image_b.png")

      assert [%Asset{file_name: "image_a.webp"}] = MediaLibrary.list_assets(default_site(), per_page: 1, page: 1, sort: :file_name)
      assert [%Asset{file_name: "image_b.webp"}] = MediaLibrary.list_assets(default_site(), per_page: 1, page: 2, sort: :file_name)
      assert [] = MediaLibrary.list_assets(default_site(), per_page: 2, page: 2, sort: :file_name)
    end
  end

  describe "count_assets" do
    test "no assets return 0" do
      assert MediaLibrary.count_assets(default_site()) == 0
    end

    test "filter by file name" do
      beacon_media_library_asset_fixture(file_name: "image_a.png")
      beacon_media_library_asset_fixture(file_name: "image_b.png")

      assert MediaLibrary.count_assets(default_site(), query: "image_a") == 1
    end
  end
end
