defmodule Beacon.RouterTest do
  use ExUnit.Case, async: true
  use Beacon.Test

  alias Beacon.Router

  test "live_session name" do
    assert {:test, :beacon_test, _} = Router.__options__(site: :test)
  end

  test "session opts" do
    assert {
             :test,
             _,
             [{:session, %{"beacon_site" => :test}}, {:root_layout, {Beacon.Web.Layouts, :runtime}}]
           } = Router.__options__(site: :test)
  end

  describe "options" do
    test "require site as atom" do
      assert_raise ArgumentError, fn -> Router.__options__([]) end
      assert_raise ArgumentError, fn -> Router.__options__(site: "string") end
    end
  end

  describe "__options__/1" do
    test "returns default session options that include session and root_layout keys when passed a site name as an atom" do
      assert Router.__options__(site: :my_site) ==
               {:my_site, :beacon_my_site,
                [
                  session: %{"beacon_site" => :my_site},
                  root_layout: {Beacon.Web.Layouts, :runtime}
                ]}
    end

    test "returns custom root_layout value when passed a root_layout value in a keyword list" do
      assert Router.__options__(site: :my_site, root_layout: {Beacon.Web.Layouts, :app}) ==
               {:my_site, :beacon_my_site,
                [
                  session: %{"beacon_site" => :my_site},
                  root_layout: {Beacon.Web.Layouts, :app}
                ]}
    end

    test "returns custom on_mount value when passed an on_mount value in a keyword list" do
      assert Router.__options__(site: :my_site, on_mount: {:struct, :atom}) ==
               {:my_site, :beacon_my_site,
                [
                  session: %{"beacon_site" => :my_site},
                  root_layout: {Beacon.Web.Layouts, :runtime},
                  on_mount: {:struct, :atom}
                ]}
    end
  end

  test "path_params" do
    assert Router.path_params("/", []) == %{}
    assert Router.path_params("/posts", ["posts"]) == %{}
    assert Router.path_params("/posts/*slug", ["posts", "2023"]) == %{"slug" => ["2023"]}
    assert Router.path_params("/posts/*slug", ["posts", "2023", "my-post"]) == %{"slug" => ["2023", "my-post"]}
    assert Router.path_params("/posts/:author", ["posts", "1-author"]) == %{"author" => "1-author"}
    assert Router.path_params("/posts/:author/:category", ["posts", "1-author", "test"]) == %{"author" => "1-author", "category" => "test"}
  end

  describe "reachable?" do
    defp config(site, opts \\ []) do
      Map.merge(
        Beacon.Config.fetch!(site),
        Enum.into(opts, %{router: Beacon.BeaconTest.ReachTestRouter})
      )
    end

    test "match existing host" do
      config = config(:host_test)
      assert Router.reachable?(config, host: "host.com", prefix: "/host_test")
    end

    test "existing nested conflicting route" do
      config = config(:not_booted)
      refute Router.reachable?(config, host: nil, prefix: "/conflict")
    end

    test "root path with no host" do
      config = config(:my_site)
      assert Router.reachable?(config, host: nil)
    end

    test "not reachable when does not match any existing host/path" do
      config = config(:my_site)
      refute Router.reachable?(config, host: nil, prefix: "/other")
    end

    test "router without beacon routes" do
      config = config(:my_site, router: Beacon.BeaconTest.NoRoutesRouter)
      refute Router.reachable?(config)
    end
  end
end
