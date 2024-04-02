defmodule Beacon.Lifecycle.AssetTest do
  use Beacon.DataCase
  import Beacon.Fixtures

  test "upload_asset" do
    refute Beacon.MediaLibrary.get_asset_by(:lifecycle_test, file_name: "image.webp")
    refute Beacon.MediaLibrary.get_asset_by(:lifecycle_test, file_name: "image-thumb.webp")

    %{site: :lifecycle_test, file_name: "image.webp"}
    |> upload_metadata_fixture()
    |> Beacon.MediaLibrary.upload()

    assert %Beacon.MediaLibrary.Asset{} = Beacon.MediaLibrary.get_asset_by(:lifecycle_test, file_name: "image.webp")
    assert %Beacon.MediaLibrary.Asset{} = Beacon.MediaLibrary.get_asset_by(:lifecycle_test, file_name: "image-thumb.webp")
  end
end
