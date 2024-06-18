defmodule Beacon.RouterTest do
  use ExUnit.Case, async: true

  alias Beacon.Router

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
end
