defmodule Beacon.Lifecycle.AssetTest do
  use Beacon.DataCase
  import Beacon.Fixtures

  test "upload_asset" do
    refute Beacon.MediaLibrary.get_asset(:lifecycle_test, "image.webp")
    refute Beacon.MediaLibrary.get_asset(:lifecycle_test, "image-thumb.webp")

    %{site: :lifecycle_test, file_name: "image.webp"}
    |> file_metadata_fixture()
    |> Beacon.Admin.MediaLibrary.upload()

    assert %Beacon.MediaLibrary.Asset{} = Beacon.MediaLibrary.get_asset(:lifecycle_test, "image.webp")
    assert %Beacon.MediaLibrary.Asset{} = Beacon.MediaLibrary.get_asset(:lifecycle_test, "image-thumb.webp")

  end
end
