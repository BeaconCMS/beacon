defmodule Beacon.Web.DataSourceTest do
  use Beacon.DataCase, async: false
  use Beacon.Test, site: :my_site
  alias Beacon.Web.DataSource

  setup do
    site = default_site()

    # we aren't passing through PageLive in these tests so we have to manually
    # enable the ErrorHandler and set the site in the Process dictionary
    # (which would normally happen in the LiveView mount)
    Process.put(:__beacon_site__, site)
    Process.flag(:error_handler, Beacon.ErrorHandler)

    [site: site]
  end

  test "live_data", %{site: site} do
    live_data = beacon_live_data_fixture()
    beacon_live_data_assign_fixture(live_data: live_data, format: :text, key: "name", value: "beacon")
    assert DataSource.live_data(site, ["foo", "bar"], %{}) == %{name: "beacon"}
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
