defmodule Beacon.WebTest do
  use ExUnit.Case, async: true

  describe "assign/2" do
    test "do not allow assigning reserved :beacon key" do
      assert_raise ArgumentError, fn -> Beacon.Web.assign(%{}, beacon: nil) end
      assert_raise ArgumentError, fn -> Beacon.Web.assign(%{}, %{beacon: nil}) end
    end
  end

  describe "assign/3" do
    test "do not allow assigning reserved :beacon key" do
      assert_raise ArgumentError, fn -> Beacon.Web.assign(%{}, :beacon, nil) end
    end
  end

  describe "assign_new/3" do
    test "do not allow assigning reserved :beacon key" do
      assert_raise ArgumentError, fn -> Beacon.Web.assign_new(%{}, :beacon, fn -> nil end) end
    end
  end
end
