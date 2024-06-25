defmodule BeaconWeb.BeaconAssignsTest do
  use Beacon.DataCase
  alias BeaconWeb.BeaconAssigns
  import Beacon.Fixtures

  @site :my_site

  setup do
    Beacon.Loader.reload_live_data_module(@site)
    [socket: %Phoenix.LiveView.Socket{assigns: %{__changed__: %{beacon: true}, beacon: %BeaconAssigns{}}}]
  end

  test "build with site" do
    assert %BeaconAssigns{
             site: @site,
             private: %{components_module: :"Elixir.BeaconWeb.LiveRenderer.6a217f0f7032720eb50a1a2fbf258463.Components"}
           } = BeaconAssigns.new(@site)
  end

  test "build with unpublished page" do
    Beacon.Loader.reload_components_module(@site)
    page = page_fixture(site: @site, path: "/blog")

    assigns = BeaconAssigns.new(@site, page, %{}, ["blog"], %{})

    assert %BeaconAssigns{
             site: @site,
             page: %{path: "/blog", title: ""},
             private: %{
               live_path: ["blog"]
             }
           } = assigns
  end

  test "build with non-persisted page" do
    page_id = Ecto.UUID.generate()
    layout_id = Ecto.UUID.generate()
    page = %Beacon.Content.Page{id: page_id, layout_id: layout_id, site: @site, path: "/blog"}

    assigns = BeaconAssigns.new(@site, page, %{}, ["blog"], %{})

    assert %BeaconAssigns{
             site: @site,
             page: %{path: "/blog", title: ""},
             private: %{
               page_id: ^page_id,
               layout_id: ^layout_id,
               live_path: ["blog"]
             }
           } = assigns
  end

  test "build with published page resolves page title" do
    Beacon.Loader.reload_components_module(@site)
    page = published_page_fixture(site: @site, path: "/blog", title: "blog index")
    Beacon.Loader.reload_page_module(@site, page.id)

    assigns = BeaconAssigns.new(@site, page, %{}, ["blog"], %{})

    assert %BeaconAssigns{
             site: @site,
             page: %{path: "/blog", title: "blog index"},
             private: %{
               live_path: ["blog"]
             }
           } = assigns
  end

  test "build with path info and query params" do
    Beacon.Loader.reload_components_module(@site)
    page = page_fixture(site: @site, path: "/blog")

    assigns = BeaconAssigns.new(@site, page, %{}, ["blog"], %{source: "search"})

    assert %BeaconAssigns{
             site: @site,
             query_params: %{source: "search"},
             private: %{
               live_path: ["blog"]
             }
           } = assigns
  end

  test "build with path params" do
    Beacon.Loader.reload_components_module(@site)
    page = page_fixture(site: @site, path: "/blog/:post")

    assigns = BeaconAssigns.new(@site, page, %{}, ["blog", "hello"], %{})

    assert %BeaconAssigns{
             site: @site,
             path_params: %{"post" => "hello"}
           } = assigns
  end

  test "build with live data" do
    Beacon.Loader.reload_components_module(@site)
    page = page_fixture(site: @site, path: "/blog")

    live_data = live_data_fixture(site: @site, path: "/blog")
    live_data_assign_fixture(live_data: live_data, format: :text, key: "customer_id", value: "123")
    Beacon.Loader.reload_live_data_module(@site)

    assigns = BeaconAssigns.new(@site, page, live_data, ["blog"], %{})

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
