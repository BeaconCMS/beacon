defmodule Beacon.RouterTest do
  use ExUnit.Case, async: true
  use Beacon.Test

  alias Beacon.Router

  describe "live session" do
    test "session name based on site" do
      assert {:beacon_test, _} = Router.__live_session__(:test)
    end

    test "include default :session option" do
      assert {_, [{:session, {Beacon.Router, :session, [:my_site, %{}]}}, _, _]} = Router.__live_session__(:my_site)
    end

    test "include default :root_layout option" do
      assert {_, [_, {:root_layout, {Beacon.Web.Layouts, :runtime}}, _]} = Router.__live_session__(:my_site)
    end

    test "include default :on_mount option" do
      assert {_, [_, _, {:on_mount, []}]} = Router.__live_session__(:my_site)
    end

    test "include extra :session" do
      assert {_, [{:session, {Beacon.Router, :session, [:my_site, %{"user" => 1}]}}, _, _]} =
               Router.__live_session__(:my_site, session: %{"user" => 1})

      assert {_, [{:session, {Beacon.Router, :session, [:my_site, {MyApp, :ensure_auth, [1]}]}}, _, _]} =
               Router.__live_session__(:my_site, session: {MyApp, :ensure_auth, [1]})
    end

    test "do not overwrite site in :session" do
      assert {_, [{:session, {Beacon.Router, :session, [:my_site, %{}]}}, _, _]} =
               Router.__live_session__(:my_site, session: %{"site" => :other})
    end

    test "overwrite :root_layout" do
      assert {_, [_, {:root_layout, {MyAppWeb, :blog_layout}}, _]} = Router.__live_session__(:my_site, root_layout: {MyAppWeb, :blog_layout})
    end

    test "overwrite :on_mount" do
      assert {_, [_, _, {:on_mount, MyAppWeb.InitAssigns}]} = Router.__live_session__(:my_site, on_mount: MyAppWeb.InitAssigns)

      assert {_, [_, _, {:on_mount, {MyAppWeb.InitAssigns, :user}}]} = Router.__live_session__(:my_site, on_mount: {MyAppWeb.InitAssigns, :user})
    end
  end

  test "require site as atom" do
    assert_raise ArgumentError, fn -> Router.validate_site!("site") end
    assert_raise ArgumentError, fn -> Router.validate_site!(nil) end
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

    test "phoenix live_view site map" do
      config2 = Map.merge(
        Beacon.Config.fetch!(:my_site),
        %{host: "host_test", prefix: "/", router: Beacon.BeaconTest.Router}
      )

      assert Router.reachable?(config2, host: "host.com", prefix: "/host_test")
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
