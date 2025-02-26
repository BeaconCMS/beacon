defmodule Beacon.Web.BeaconAssignsTest do
  use Beacon.DataCase
  alias Beacon.Web.BeaconAssigns
  use Beacon.Test, site: :my_site

  @site :my_site

  setup do
    site = default_site()

    # we aren't passing through PageLive in these tests so we have to manually
    # enable the ErrorHandler and set the site in the Process dictionary
    # (which would normally happen in the LiveView mount)
    Process.put(:__beacon_site__, site)
    Process.flag(:error_handler, Beacon.ErrorHandler)

    [site: site]
  end

  test "build with site", %{site: site} do
    assert %BeaconAssigns{
             site: @site,
             private: %{components_module: :"Elixir.Beacon.Web.LiveRenderer.6a217f0f7032720eb50a1a2fbf258463.Components"}
           } = BeaconAssigns.new(site)
  end

  test "build with published page resolves page title" do
    page = beacon_published_page_fixture(path: "/blog", title: "blog index")

    assigns = BeaconAssigns.new(page, path_info: ["blog"])

    assert %BeaconAssigns{
             site: @site,
             page: %{path: "/blog", title: "blog index"},
             private: %{
               live_path: ["blog"]
             }
           } = assigns
  end

  test "build with unpublished page stored in the database" do
    page = beacon_page_fixture(path: "/blog", title: "blog index")

    assigns = BeaconAssigns.new(page, path_info: ["blog"])

    assert %BeaconAssigns{
             site: @site,
             page: %{path: "/blog", title: "blog index"},
             private: %{
               live_path: ["blog"]
             }
           } = assigns
  end

  test "build with new in-memory page " do
    page = %Beacon.Content.Page{site: @site, path: "/blog", title: "blog index"}

    assigns = BeaconAssigns.new(page, path_info: ["blog"])

    assert %BeaconAssigns{
             site: @site,
             page: %{path: "/blog", title: "blog index"},
             private: %{
               live_path: ["blog"]
             }
           } = assigns
  end

  test "build with path info and query params" do
    page = beacon_published_page_fixture(path: "/blog")

    assigns = BeaconAssigns.new(page, path_info: ["blog"], query_params: %{source: "search"})

    assert %BeaconAssigns{
             site: @site,
             query_params: %{source: "search"},
             private: %{
               live_path: ["blog"]
             }
           } = assigns
  end

  test "build with path params" do
    page = beacon_published_page_fixture(path: "/blog/:post")

    assigns = BeaconAssigns.new(page, path_info: ["blog", "hello"])

    assert %BeaconAssigns{
             site: @site,
             path_params: %{"post" => "hello"}
           } = assigns
  end

  test "build with live data" do
    page = beacon_published_page_fixture(path: "/blog")

    live_data = beacon_live_data_fixture(path: "/blog")
    beacon_live_data_assign_fixture(live_data: live_data, format: :text, key: "customer_id", value: "123")

    assigns = BeaconAssigns.new(page, path_info: ["blog"])

    assert %BeaconAssigns{
             site: @site,
             private: %{
               live_data_keys: [:customer_id]
             }
           } = assigns
  end
end
