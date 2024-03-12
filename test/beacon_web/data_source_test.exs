defmodule BeaconWeb.DataSourceTest do
  use Beacon.DataCase, async: false
  alias BeaconWeb.DataSource

  @site :my_site

  test "live_data" do
    live_data = live_data_fixture(site: @site)
    live_data_assign_fixture(live_data: live_data, format: :text, key: "name", value: "beacon")
    assert DataSource.live_data(@site, ["foo", "bar"], %{}) == %{name: "beacon"}
  end

  describe "page_title" do
    test "renders static content" do
      page = published_page_fixture(site: @site, title: "my title")
      assert DataSource.page_title(page.site, page.id, %{}) == "my title"
    end

    test "renders snippet" do
      page = published_page_fixture(site: @site, title: "{{ page.path | upcase }}")
      assert DataSource.page_title(page.site, page.id, %{}) == "/HOME"
    end
  end
end
