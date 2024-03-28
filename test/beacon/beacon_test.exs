defmodule Beacon.BeaconTest do
  use Beacon.DataCase, async: false

  describe "boot" do
    test "disable skip_boot config" do
      assert config().skip_boot?
      Beacon.boot(:boot_test)
      refute config().skip_boot?
    end
  end

  defp config do
    Beacon.Config.fetch!(:boot_test)
  end
end
