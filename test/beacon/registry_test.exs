defmodule Beacon.RegistryTest do
  use ExUnit.Case, async: true

  alias Beacon.Registry

  test "registered_sites" do
    registered_sites = Registry.registered_sites()
    assert Enum.sort(registered_sites) == [:data_source_test, :my_site]
  end

  describe "config!" do
    test "return site config for existing sites" do
      assert Registry.config!(:my_site) == %Beacon.Config{
               site: :my_site,
               data_source: Beacon.BeaconTest.BeaconDataSource,
               css_compiler: CSSCompilerMock,
               live_socket_path: "/custom_live",
               safe_code_check: false
             }
    end

    test "raise when not found" do
      assert_raise RuntimeError, ~r/Site :invalid was not found/, fn ->
        Registry.config!(:invalid)
      end
    end
  end
end
