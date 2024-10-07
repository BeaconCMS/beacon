defmodule Beacon.TestTest do
  use Beacon.DataCase

  use Beacon.Test, site: :not_booted

  test "default_site" do
    assert default_site() == :not_booted
  end

  test "fixture with default site" do
    assert %{site: :not_booted} = beacon_page_fixture()
    assert %{site: :not_booted, path: "/test"} = beacon_page_fixture(path: "/test")
  end

  test "override default site" do
    assert %{site: :my_site} = beacon_page_fixture(site: :my_site, path: "/a")
    assert %{site: :my_site} = beacon_page_fixture(%{site: :my_site, path: "/b"})
    assert %{site: :my_site} = beacon_page_fixture(%{"site" => :my_site, "path" => "/c"})
  end
end
