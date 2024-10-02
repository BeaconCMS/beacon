defmodule Beacon.Web.DataSourceTest do
  use Beacon.DataCase, async: false
  use Beacon.Test, site: :my_site
  alias Beacon.Web.DataSource
  alias Beacon.Loader

  test "live_data" do
    live_data = beacon_live_data_fixture()
    beacon_live_data_assign_fixture(live_data: live_data, format: :text, key: "name", value: "beacon")
    Loader.reload_live_data_module(default_site())
    assert DataSource.live_data(default_site(), ["foo", "bar"], %{}) == %{name: "beacon"}
  end

  describe "page_title" do
    test "renders static content" do
      page = beacon_published_page_fixture(site: default_site(), title: "my title")
      Loader.reload_page_module(page.site, page.id)
      assert DataSource.page_title(page.site, page.id, %{}) == "my title"
    end

    test "renders snippet" do
      page = beacon_published_page_fixture(site: default_site(), title: "{{ page.path | upcase }}")
      Loader.reload_snippets_module(default_site())
      Loader.reload_page_module(page.site, page.id)
      assert DataSource.page_title(page.site, page.id, %{}) == "/HOME"
    end
  end
end
