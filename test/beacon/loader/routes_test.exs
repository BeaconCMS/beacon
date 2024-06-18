defmodule Beacon.Loader.RoutesTest do
  use ExUnit.Case, async: true

  # Beacon.Loader.fetch_routes_module(:my_site)
  import :"Elixir.BeaconWeb.LiveRenderer.6a217f0f7032720eb50a1a2fbf258463.Routes"

  test "beacon_asset_path" do
    assert beacon_asset_path("logo.webp") == "/beacon_assets/my_site/logo.webp"
  end

  test "beacon_asset_url" do
    assert beacon_asset_url("logo.webp") == "http://localhost:4000/beacon_assets/my_site/logo.webp"
  end

  test "sigil_P" do
    assert ~P"/contact" == "/contact"
  end
end
