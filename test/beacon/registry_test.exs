defmodule Beacon.RegistryTest do
  use ExUnit.Case, async: false

  test "running_sites" do
    running_sites = Beacon.Registry.running_sites()

    assert Enum.sort(running_sites) == [
             :booted,
             :data_source_test,
             :default_meta_tags_test,
             :lifecycle_test,
             :lifecycle_test_fail,
             :my_site,
             :not_booted,
             :s3_site
           ]
  end
end
