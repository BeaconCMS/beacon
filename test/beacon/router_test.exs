defmodule Beacon.RouterTest do
  use ExUnit.Case, async: true

  alias Beacon.Router

  test "live_session name" do
    assert {:beacon_test, _} = Router.__options__(name: :test)
  end

  test "session opts" do
    assert {
             _,
             [{:session, %{"beacon_site" => :test}}, {:root_layout, {BeaconWeb.Layouts, :runtime}}]
           } = Router.__options__(name: :test)
  end

  describe "options" do
    test "require site name as atom" do
      assert_raise ArgumentError, fn -> Router.__options__([]) end
      assert_raise ArgumentError, fn -> Router.__options__(name: "string") end
    end
  end

  defmodule RouterSimple do
    use Beacon.BeaconTest, :router
    import Beacon.Router

    scope "/" do
      beacon_admin "/admin"
      beacon_site "/", name: :site
    end
  end

  defmodule RouterNested do
    use Beacon.BeaconTest, :router
    import Beacon.Router

    scope "/parent" do
      scope "/nested" do
        beacon_admin "/admin"
        beacon_site "/site", name: :site
      end
    end
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :beacon
  end

  describe "beacon_admin_path" do
    import Beacon.Router, only: [beacon_admin_path: 2, beacon_admin_path: 3]

    setup do
      start_supervised!(Endpoint)
      :ok
    end

    test "plain route" do
      socket = %Phoenix.LiveView.Socket{endpoint: Endpoint, router: RouterSimple}

      assert beacon_admin_path(socket, "/pages") == "/admin/pages"
      assert beacon_admin_path(socket, :pages, %{foo: :bar}) == "/admin/pages?foo=bar"
    end

    test "nested route" do
      socket = %Phoenix.LiveView.Socket{endpoint: Endpoint, router: RouterNested}

      assert beacon_admin_path(socket, "/pages") == "/parent/nested/admin/pages"
      assert beacon_admin_path(socket, :pages, %{foo: :bar}) == "/parent/nested/admin/pages?foo=bar"
    end
  end

  describe "beacon_asset_path" do
    import Beacon.Router, only: [beacon_asset_path: 2]

    test "plain route" do
      beacon = %{router: RouterSimple}

      assert beacon_asset_path(beacon, "file.jpg") == "/beacon_assets/file.jpg?site=site"
    end

    test "nested route" do
      beacon = %{router: RouterNested}

      assert beacon_asset_path(beacon, "file.jpg") == "/parent/nested/site/beacon_assets/file.jpg?site=site"
    end
  end
end
