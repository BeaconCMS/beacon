defmodule Beacon.BeaconTest do
  use Beacon.DataCase, async: false

  describe "boot" do
    test "disable skip_boot config" do
      assert config().skip_boot?
      Beacon.boot(:not_booted)
      refute config().skip_boot?
    end
  end

  describe "apply_mfa" do
    test "valid module" do
      assert Beacon.apply_mfa(String, :trim, [" beacon "]) == "beacon"
    end

    test "display context" do
      assert_raise Beacon.RuntimeError, ~r/beacon_test/, fn ->
        Beacon.apply_mfa(:invalid, :foo, [], context: %{source: "beacon_test"})
      end
    end

    test "invalid module" do
      assert_raise Beacon.RuntimeError, fn ->
        Beacon.apply_mfa(:invalid, :foo, [])
      end
    end
  end

  defp config do
    Beacon.Config.fetch!(:not_booted)
  end
end
