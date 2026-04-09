defmodule Beacon.Web.DataSourceTest do
  use Beacon.DataCase, async: false
  use Beacon.Test, site: :my_site
  alias Beacon.Web.DataSource

  setup do
    site = default_site()

    [site: site]
  end

  describe "live_data" do
    test "with existing data", %{site: site} do
      live_data = beacon_live_data_fixture()
      beacon_live_data_assign_fixture(live_data: live_data, format: :text, key: "name", value: "beacon")
      beacon_published_page_fixture(path: "/foo/bar")
      assert DataSource.live_data(site, ["foo", "bar"], %{}) == %{name: "beacon"}
    end

    test "query params defaults to empty map", %{site: site} do
      live_data = beacon_live_data_fixture()
      beacon_live_data_assign_fixture(live_data: live_data, format: :text, key: "name", value: "beacon")
      beacon_published_page_fixture(path: "/foo/bar")
      assert DataSource.live_data(site, ["foo", "bar"]) == %{name: "beacon"}
    end
  end

  describe "page_title" do
    test "renders static content", %{site: site} do
      page = beacon_published_page_fixture(site: site, title: "my title")
      assert DataSource.page_title(page, %{}) == "my title"
    end

    test "renders snippet", %{site: site} do
      page = beacon_published_page_fixture(site: site, title: "{{ page.path | upcase }}")
      assert DataSource.page_title(page, %{}) == "/HOME"
    end
  end
end
