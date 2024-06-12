defmodule Beacon.RouterTest do
  use ExUnit.Case, async: true

  import Beacon.Router, only: [beacon_path: 2, beacon_path: 3]
  alias Beacon.Router
  alias BeaconWeb.BeaconAssigns

  @endpoit Beacon.BeaconTest.Endpoint

  defmodule RouterSimple do
    use Phoenix.Router
    use Beacon.Router
    import Plug.Conn
    import Phoenix.LiveView.Router

    scope "/" do
      beacon_site "/my_site", site: :my_site
    end
  end

  defmodule RouterNested do
    use Phoenix.Router
    use Beacon.Router
    import Plug.Conn
    import Phoenix.LiveView.Router

    scope "/parent" do
      scope "/nested" do
        beacon_site "/", site: :my_site
      end
    end
  end

  test "live_session name" do
    assert {:test, :beacon_test, _} = Router.__options__(site: :test)
  end

  test "session opts" do
    assert {
             :test,
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

  test "path_params" do
    assert Router.path_params("/", []) == %{}
    assert Router.path_params("/posts", ["posts"]) == %{}
    assert Router.path_params("/posts/*slug", ["posts", "2023"]) == %{"slug" => ["2023"]}
    assert Router.path_params("/posts/*slug", ["posts", "2023", "my-post"]) == %{"slug" => ["2023", "my-post"]}
    assert Router.path_params("/posts/:author", ["posts", "1-author"]) == %{"author" => "1-author"}
    assert Router.path_params("/posts/:author/:category", ["posts", "1-author", "test"]) == %{"author" => "1-author", "category" => "test"}
  end

  describe "beacon_path" do
    test "plain route" do
      beacon_assigns = :my_site |> BeaconAssigns.build() |> BeaconAssigns.build(@endpoit, RouterSimple)

      assert beacon_path(beacon_assigns, "/contact") == "/my_site/contact"
      assert beacon_path(beacon_assigns, "/contact", %{source: :search}) == "/my_site/contact?source=search"
    end

    test "nested route" do
      beacon_assigns = :my_site |> BeaconAssigns.build() |> BeaconAssigns.build(@endpoit, RouterNested)

      assert beacon_path(beacon_assigns, "/contact") == "/parent/nested/contact"
      assert beacon_path(beacon_assigns, "/contact", %{source: :search}) == "/parent/nested/contact?source=search"
    end
  end
end
