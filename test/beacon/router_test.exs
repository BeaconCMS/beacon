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
    setup do
      site = :host_test
      config = Beacon.Config.fetch!(site)
      [config: config]
    end

    test "match existing host", %{config: config} do
      valid_host = "host.com"
      assert Router.reachable?(config, host: valid_host)
    end

    test "with no specific host", %{config: config} do
      assert Router.reachable?(config, host: nil)
    end

    test "do not match any existing host/path", %{config: config} do
      refute Router.reachable?(config, host: nil, prefix: "/nested/invalid")
    end
  end
end
