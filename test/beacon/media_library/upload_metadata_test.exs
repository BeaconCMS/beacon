defmodule Beacon.MediaLibrary.UploadMetadataTest do
  use Beacon.DataCase, async: true

  alias Beacon.MediaLibrary.UploadMetadata

  describe "key_for" do
    test "downcases" do
      key = UploadMetadata.key_for(%{name: "ZZZ.JPG", site: "site"})
      assert ^key = "site/zzz.jpg"
    end

    test "converts whitespace, _ and . to dashes" do
      key = UploadMetadata.key_for(%{name: "Some Name\u00A0with_weird.white_space.jpg", site: "site"})
      assert ^key = "site/some-name-with-weird-white-space.jpg"
    end

    test "whitelists alphnumeric chars as well as _ -" do
      key = UploadMetadata.key_for(%{name: "adé-bob_Name;fGhfg*.jpg", site: "site"})
      assert ^key = "site/adé-bob-namefghfg.jpg"
    end
  end
end
