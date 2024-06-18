defmodule BeaconWeb.BeaconAssignsTest do
  use Beacon.DataCase
  alias BeaconWeb.BeaconAssigns
  import Beacon.Fixtures

  setup do
    [socket: %Phoenix.LiveView.Socket{assigns: %{__changed__: %{beacon: true}, beacon: %BeaconAssigns{}}}]
  end

  test "build with site" do
    assert %BeaconAssigns{
             private: %{components_module: :"Elixir.BeaconWeb.LiveRenderer.6a217f0f7032720eb50a1a2fbf258463.Components"},
             site: :my_site,
             page: %{path: nil, title: nil},
             path_params: %{},
             query_params: %{}
           } = BeaconAssigns.build(:my_site)
  end

  test "build with path info and query params" do
    Beacon.Loader.reload_components_module(:my_site)
    published_page_fixture(path: "/blog")

    assigns =
      :my_site
      |> BeaconAssigns.build()
      |> BeaconAssigns.build(["/blog"], %{source: "search"})

    assert %BeaconAssigns{
             private: %{
               components_module: :"Elixir.BeaconWeb.LiveRenderer.6a217f0f7032720eb50a1a2fbf258463.Components",
               live_data_keys: [],
               live_path: ["/blog"]
             },
             site: :my_site,
             path_params: %{},
             query_params: %{source: "search"},
             page: %{path: "/blog", title: "home"}
           } = assigns
  end

  test "update/3", %{socket: socket} do
    assert %{assigns: %{beacon: %BeaconAssigns{site: "one"}}} = BeaconAssigns.update(socket, :site, "one")
    assert %{assigns: %{beacon: %BeaconAssigns{site: "two"}}} = BeaconAssigns.update(socket, :site, "two")
  end
end
