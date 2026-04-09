defmodule Beacon.Web.BeaconAssignsTest do
  use Beacon.DataCase
  alias Beacon.Web.BeaconAssigns
  use Beacon.Test, site: :my_site

  @site :my_site

  test "build with site" do
    assert %BeaconAssigns{
             site: @site,
             page: %{path: nil, title: nil},
             private: %{
               live_data_keys: [],
               live_path: [],
               variant_roll: nil
             }
           } = BeaconAssigns.new(@site)
  end
end
