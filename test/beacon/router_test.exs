defmodule Beacon.RouterTest do
  use ExUnit.Case, async: true

  alias Beacon.Router

  test "live_session name" do
    assert {:beacon_test, _} = Router.__options__(site: :test)
  end

  test "session opts" do
    assert {
             _,
             [{:session, %{"beacon_site" => :test}}, {:root_layout, {BeaconWeb.Layouts, :runtime}}]
           } = Router.__options__(site: :test)
  end

  describe "options" do
    test "require site as atom" do
      assert_raise ArgumentError, fn -> Router.__options__([]) end
      assert_raise ArgumentError, fn -> Router.__options__(site: "string") end
    end
  end

  describe "admin options" do
    test "options are optional, assigns agent" do
      assert [
               {:on_mount, [BeaconWeb.Admin.Hooks.AssignAgent]},
               {:root_layout, {BeaconWeb.Layouts, :admin}}
             ] = Router.__admin_session_opts__([])
    end

    test "assigns on_mount" do
      assert [
               {:on_mount, [SomeHook, BeaconWeb.Admin.Hooks.AssignAgent]},
               {:root_layout, {BeaconWeb.Layouts, :admin}}
             ] = Router.__admin_session_opts__(on_mount: [SomeHook])
    end

    test "allows setting of AssignAgent" do
      assert [
               {:on_mount, [SomeHook, BeaconWeb.Admin.Hooks.AssignAgent, SomeOtherHook]},
               {:root_layout, {BeaconWeb.Layouts, :admin}}
             ] = Router.__admin_session_opts__(on_mount: [SomeHook, BeaconWeb.Admin.Hooks.AssignAgent, SomeOtherHook])
    end

    test "dose not assign root_layout" do
      assert_raise ArgumentError, fn -> Router.__admin_session_opts__(root_layout: {BeaconWeb.Layouts, :runtime}) end
    end

    test "dose not assign layout" do
      assert_raise ArgumentError, fn -> Router.__admin_session_opts__(layout: {BeaconWeb.Layouts, :runtime}) end
    end
  end

  defmodule RouterSimple do
    use Beacon.BeaconTest, :router
    use Beacon.Router

    scope "/" do
      beacon_admin "/admin"
    end
  end

  defmodule RouterNested do
    use Beacon.BeaconTest, :router
    use Beacon.Router

    scope "/parent" do
      scope "/nested" do
        beacon_admin "/admin"
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
      attrs = %Beacon.BeaconAttrs{site: :site, prefix: ""}

      assert beacon_asset_path(attrs, "file.jpg") == "/beacon_assets/file.jpg?site=site"
    end

    test "nested route" do
      attrs = %Beacon.BeaconAttrs{site: :site, prefix: "parent/nested"}

      assert beacon_asset_path(attrs, "file.jpg") == "/parent/nested/beacon_assets/file.jpg?site=site"
    end
  end

  describe "lookup" do
    # we don't care about values in this test but we create the same structure
    # see Router.add_page/4
    @value {nil, nil, nil, nil, nil, nil}

    setup do
      [table: :ets.new(:beacon_router_test, [:ordered_set, :protected])]
    end

    test "not existing path", %{table: table} do
      refute Router.lookup_path(table, :test, ["home"])
    end

    test "exact match on static paths", %{table: table} do
      Router.add_page(table, :test, "", @value)
      Router.add_page(table, :test, "home", @value)
      Router.add_page(table, :test, "blog/posts/2020-01-my-post", @value)

      assert {{:test, ""}, _} = Router.lookup_path(table, :test, [])
      assert {{:test, "home"}, _} = Router.lookup_path(table, :test, ["home"])
      assert {{:test, "blog/posts/2020-01-my-post"}, _} = Router.lookup_path(table, :test, ["blog", "posts", "2020-01-my-post"])
    end

    test "multiple dynamic segments", %{table: table} do
      Router.add_page(table, :test, "/users/:user_id/posts/:id/edit", @value)

      assert {{:test, "/users/:user_id/posts/:id/edit"}, _} = Router.lookup_path(table, :test, ["users", "1", "posts", "100", "edit"])
    end

    test "dynamic segments lookup in batch", %{table: table} do
      Router.add_page(table, :test, "/:page", @value)
      Router.add_page(table, :test, "/users/:user_id/posts/:id/edit", @value)

      assert {{:test, "/:page"}, _} = Router.lookup_path(table, :test, ["home"], 1)
      assert {{:test, "/users/:user_id/posts/:id/edit"}, _} = Router.lookup_path(table, :test, ["users", "1", "posts", "100", "edit"], 1)
    end

    test "dynamic segments with same prefix", %{table: table} do
      Router.add_page(table, :test, "/posts/:post_id", @value)
      Router.add_page(table, :test, "/posts/authors/:author_id", @value)

      assert {{:test, "/posts/:post_id"}, _} = Router.lookup_path(table, :test, ["posts", "1"])
      assert {{:test, "/posts/authors/:author_id"}, _} = Router.lookup_path(table, :test, ["posts", "authors", "1"])
    end

    test "catch all", %{table: table} do
      Router.add_page(table, :test, "/posts/*slug", @value)

      assert {{:test, "/posts/*slug"}, _} = Router.lookup_path(table, :test, ["posts", "2022", "my-post"])
    end

    test "catch all with existing path with same prefix", %{table: table} do
      Router.add_page(table, :test, "/press/releases/*slug", @value)
      Router.add_page(table, :test, "/press/releases", @value)

      assert {{:test, "/press/releases/*slug"}, _} = Router.lookup_path(table, :test, ["press", "releases", "announcement"])
      assert {{:test, "/press/releases"}, _} = Router.lookup_path(table, :test, ["press", "releases"])
    end

    test "catch all must match at least 1 segment", %{table: table} do
      Router.add_page(table, :test, "/posts/*slug", @value)

      refute Router.lookup_path(table, :test, ["posts"])
    end

    test "mixed dynamic segments", %{table: table} do
      Router.add_page(table, :test, "/posts/:year/*slug", @value)

      assert {{:test, "/posts/:year/*slug"}, _} = Router.lookup_path(table, :test, ["posts", "2022", "my-post"])
    end
  end
end
