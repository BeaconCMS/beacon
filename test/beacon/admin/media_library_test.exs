defmodule Beacon.Admin.MediaLibraryTest do
  use Beacon.DataCase, async: true

  alias Beacon.Admin.MediaLibrary
  alias Beacon.Admin.MediaLibrary.Asset
  import Beacon.Fixtures

  test "search by file name" do
    media_library_asset_fixture(file_name: "my_file.webp")
    media_library_asset_fixture(file_name: "other_file.webp")

    assert [%Asset{file_name: "my_file.webp"}] = MediaLibrary.search("my")
  end

  test "soft delete" do
    asset = media_library_asset_fixture(file_name: "my_file.png")

    assert {:ok, %Asset{deleted_at: deleted_at, updated_at: updated_at}} = MediaLibrary.soft_delete_asset(asset)
    assert deleted_at
    assert updated_at == asset.updated_at
  end

  test "upload asset, converts to webp by default" do
    metadata = file_metadata_fixture(file_name: "my_file.png")
    Beacon.Config.fetch!(:my_site)
    assert {:ok, %Asset{file_name: "my_file.webp", media_type: "image/webp"}} = MediaLibrary.upload(metadata)
  end
end
