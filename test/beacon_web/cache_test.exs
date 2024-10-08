defmodule Beacon.Web.CacheTest do
  use Beacon.Web.ConnCase, async: true
  use Beacon.Test, site: :my_site
  alias Beacon.Web.Cache

  setup do
    asset = beacon_media_library_asset_fixture()
    asset = %{asset | id: "9272fab9-0369-4394-8458-380b889600fd", updated_at: ~U[2024-04-02 20:32:12Z]}
    [asset: asset]
  end

  test "last_modified", %{asset: asset} do
    assert Cache.last_modified(asset) == {{2024, 4, 2}, {20, 32, 12}}
  end

  test "to_rfc1123" do
    assert Cache.to_rfc1123({{2024, 4, 2}, {20, 32, 12}}) == "Tue, 02 Apr 2024 20:32:12 GMT"
  end
end
