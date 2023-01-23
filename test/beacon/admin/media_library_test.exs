defmodule Beacon.Admin.MediaLibraryTest do
  use Beacon.DataCase, async: true

  alias Beacon.Admin.MediaLibrary
  alias Beacon.Admin.MediaLibrary.Asset
  alias Beacon.Fixtures

  describe "search" do
    test "by file name" do
      Fixtures.media_library_asset_fixture(file_name: "my_file.png")
      Fixtures.media_library_asset_fixture(file_name: "other_file.png")

      assert [%Asset{file_name: "my_file.png"}] = MediaLibrary.search("my")
    end
  end
end
