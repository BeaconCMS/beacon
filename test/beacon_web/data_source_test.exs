defmodule Beacon.Web.DataSourceTest do
  use Beacon.DataCase, async: false
  alias Beacon.Web.DataSource
  alias Beacon.Loader

  @site :my_site

  test "live_data" do
    live_data = live_data_fixture(site: @site)
    live_data_assign_fixture(live_data: live_data, format: :text, key: "name", value: "beacon")
    Loader.reload_live_data_module(@site)
    assert DataSource.live_data(@site, ["foo", "bar"], %{}) == %{name: "beacon"}
  end

  describe "page_title" do
    test "renders static content" do
      page = published_page_fixture(site: @site, title: "my title")
      Loader.reload_page_module(page.site, page.id)
      assert DataSource.page_title(page.site, page.id, %{}) == "my title"
    end

    test "renders snippet" do
      page = published_page_fixture(site: @site, title: "{{ page.path | upcase }}")
      Loader.reload_snippets_module(@site)
      Loader.reload_page_module(page.site, page.id)
      assert DataSource.page_title(page.site, page.id, %{}) == "/HOME"
    end
  end
end
