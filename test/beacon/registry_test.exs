defmodule Beacon.RegistryTest do
  use ExUnit.Case, async: false

  test "running_sites" do
    running_sites = Beacon.Registry.running_sites()
    assert Enum.sort(running_sites) == [:data_source_test, :default_meta_tags_test, :lifecycle_test, :lifecycle_test_fail, :my_site, :s3_site]
  end

  test "update_config" do
    # register a config in the test process to make Registry.update_value/3 work
    assert %Beacon.Config{live_socket_path: "/custom_live"} = config = Beacon.Registry.config!(:my_site)
    Registry.register(Beacon.Registry, {:site, :test_update_config}, config)

    assert %Beacon.Config{live_socket_path: "/test_update_config"} =
             Beacon.Registry.update_config(:test_update_config, fn config ->
               %{config | live_socket_path: "/test_update_config"}
             end)
  end

  describe "config!" do
    test "return site config for existing sites" do
      assert %Beacon.Config{
               css_compiler: Beacon.TailwindCompiler,
               authorization_source: Beacon.BeaconTest.BeaconAuthorizationSource,
               live_socket_path: "/custom_live",
               safe_code_check: false,
               site: :my_site,
               tailwind_config: tailwind_config
             } = Beacon.Registry.config!(:my_site)

      assert tailwind_config =~ "tailwind.config.templates.js.eex"
    end

    test "raise when not found" do
      assert_raise RuntimeError, ~r/site :invalid was not found/, fn ->
        Beacon.Registry.config!(:invalid)
      end
    end
  end
end
