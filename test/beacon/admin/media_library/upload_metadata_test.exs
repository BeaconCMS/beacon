defmodule Beacon.Admin.MediaLibrary.UploadMetadataTest do
  use Beacon.DataCase, async: true

  alias Beacon.Admin.MediaLibrary.UploadMetadata

  describe "key_for" do
    test "converts whitespace and . to dashes" do
      key = UploadMetadata.key_for(%{name: "some name\u00A0with_weird.white_space.jpg", site: "site"})
      assert ^key = "site/some-name-with_weird-white_space.jpg"
    end

    test "whitelists alphnumeric chars as well as _ -" do
      key = UploadMetadata.key_for(%{name: "adé-bob_name;fghfg*.jpg", site: "site"})
      assert ^key = "site/adé-bob_namefghfg.jpg"
    end
  end
end
