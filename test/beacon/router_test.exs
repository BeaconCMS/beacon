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
    assert {_, _, [private: %{beacon: %{site: "test", live_socket_path: "/live"}}]} = Router.__options__(name: "test")
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

  defmodule RouterSimple do
    use Beacon.BeaconTest, :router
    import Beacon.Router

    scope "/" do
      beacon_admin "/admin"
    end
  end

  defmodule RouterNested do
    use Beacon.BeaconTest, :router
    import Beacon.Router

    scope "/outer" do
      scope "/nested" do
        beacon_admin "/admin"
      end
    end
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :beacon
  end

  test "beacon_admin_path" do
    socket = %Phoenix.LiveView.Socket{endpoint: Endpoint, router: RouterSimple}
    import Beacon.Router, only: [beacon_admin_path: 2, beacon_admin_path: 3]
    start_supervised!(Endpoint)

    assert beacon_admin_path(socket, "/pages") == "/admin/pages"
    assert beacon_admin_path(socket, :pages, %{foo: :bar}) == "/admin/pages?foo=bar"
  end

  test "beacon_admin_path nested" do
    socket = %Phoenix.LiveView.Socket{endpoint: Endpoint, router: RouterNested}
    import Beacon.Router, only: [beacon_admin_path: 2]
    start_supervised!(Endpoint)

    assert beacon_admin_path(socket, "/pages") == "/outer/nested/admin/pages"
  end
end
