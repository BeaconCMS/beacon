defmodule Beacon.RouterTest do
  use ExUnit.Case, async: true

  alias Beacon.Router

  test "live_session name" do
    assert {:beacon_test, _, _} = Router.__options__(name: "test")
  end

  test "session opts" do
    assert {
             _,
             [{:session, %{"beacon_site" => "test"}}, {:root_layout, {BeaconWeb.Layouts, :runtime}}],
             _
           } = Router.__options__(name: "test")
  end

  test "router opts" do
    assert {_, _, [private: %{beacon: %{live_socket_path: "/live"}}]} = Router.__options__(name: "test")
  end

  describe "options" do
    test "require site name as string" do
      assert_raise ArgumentError, fn -> Router.__options__([]) end
      assert_raise ArgumentError, fn -> Router.__options__(name: :atom) end
    end

    test "override live_socket path" do
      assert {_, _, [private: %{beacon: %{live_socket_path: "/live_custom"}}]} = Router.__options__(name: "test", live_socket_path: "/live_custom")
    end
  end
end
