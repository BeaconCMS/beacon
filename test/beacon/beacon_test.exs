defmodule Beacon.BeaconTest do
  use Beacon.DataCase, async: false

  describe "boot" do
    test "disable skip_boot config" do
      assert config().skip_boot?
      Beacon.boot(:not_booted)
      refute config().skip_boot?
    end
  end

  defp config do
    Beacon.Config.fetch!(:not_booted)
  end
end
