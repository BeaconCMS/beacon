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

    [
      socket: %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{beacon: true}, beacon: %BeaconAssigns{}}
      },
      site: site
    ]
  end

  test "build with site", %{site: site} do
    assert %BeaconAssigns{
             site: @site,
             private: %{components_module: :"Elixir.Beacon.Web.LiveRenderer.6a217f0f7032720eb50a1a2fbf258463.Components"}
           } = BeaconAssigns.new(site)
  end

  test "build with published page resolves page title", %{site: site} do
    page = beacon_published_page_fixture(path: "/blog", title: "blog index")

    assigns = BeaconAssigns.new(site, page, %{}, ["blog"], %{}, :beacon)

    assert %BeaconAssigns{
             site: @site,
             page: %{path: "/blog", title: "blog index"},
             private: %{
               live_path: ["blog"]
             }
           } = assigns
  end

  test "build with path info and query params", %{site: site} do
    page = beacon_published_page_fixture(path: "/blog")

    assigns = BeaconAssigns.new(site, page, %{}, ["blog"], %{source: "search"}, :beacon)

    assert %BeaconAssigns{
             site: @site,
             query_params: %{source: "search"},
             private: %{
               live_path: ["blog"]
             }
           } = assigns
  end

  test "build with path params", %{site: site} do
    page = beacon_published_page_fixture(path: "/blog/:post")

    assigns = BeaconAssigns.new(site, page, %{}, ["blog", "hello"], %{}, :beacon)

    assert %BeaconAssigns{
             site: @site,
             path_params: %{"post" => "hello"}
           } = assigns
  end

  test "build with live data", %{site: site} do
    page = beacon_published_page_fixture(path: "/blog")

    live_data = beacon_live_data_fixture(path: "/blog")
    beacon_live_data_assign_fixture(live_data: live_data, format: :text, key: "customer_id", value: "123")

    assigns = BeaconAssigns.new(site, page, live_data, ["blog"], %{}, :beacon)

    assert %BeaconAssigns{
             site: @site,
             private: %{
               live_data_keys: [:customer_id]
             }
           } = assigns
  end

  test "update/3", %{socket: socket} do
    assert %{assigns: %{beacon: %BeaconAssigns{site: "one"}}} = BeaconAssigns.update(socket, :site, "one")
    assert %{assigns: %{beacon: %BeaconAssigns{site: "two"}}} = BeaconAssigns.update(socket, :site, "two")
  end
end
