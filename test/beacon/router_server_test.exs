defmodule Beacon.RouterServerTest do
  use Beacon.DataCase, async: false

  alias Beacon.RouterServer

  setup do
    RouterServer.del_pages(:my_site)
  end

  describe "lookup by path" do
    test "not existing path" do
      refute RouterServer.lookup_path(:my_site, ["home"])
    end

    test "exact match on static paths" do
      RouterServer.add_page(:my_site, "1", "/")
      RouterServer.add_page(:my_site, "2", "/about")
      RouterServer.add_page(:my_site, "3", "/blog/posts/2020-01-my-post")

      assert {"/", "1"} = RouterServer.lookup_path(:my_site, [])
      assert {"/about", "2"} = RouterServer.lookup_path(:my_site, ["about"])
      assert {"/blog/posts/2020-01-my-post", "3"} = RouterServer.lookup_path(:my_site, ["blog", "posts", "2020-01-my-post"])
    end

    test "multiple dynamic segments" do
      RouterServer.add_page(:my_site, "1", "/users/:user_id/posts/:id/edit")

      assert {"/users/:user_id/posts/:id/edit", "1"} = RouterServer.lookup_path(:my_site, ["users", "1", "posts", "100", "edit"])
    end

    test "dynamic segments lookup in batch" do
      RouterServer.add_page(:my_site, "1", "/:page")
      RouterServer.add_page(:my_site, "2", "/users/:user_id/posts/:id/edit")

      assert {"/:page", "1"} = RouterServer.lookup_path(:my_site, ["home"], 1)
      assert {"/users/:user_id/posts/:id/edit", "2"} = RouterServer.lookup_path(:my_site, ["users", "1", "posts", "100", "edit"], 1)
    end

    test "dynamic segments with same prefix" do
      RouterServer.add_page(:my_site, "1", "/posts/:post_id")
      RouterServer.add_page(:my_site, "2", "/posts/authors/:author_id")

      assert {"/posts/:post_id", "1"} = RouterServer.lookup_path(:my_site, ["posts", "1"])
      assert {"/posts/authors/:author_id", "2"} = RouterServer.lookup_path(:my_site, ["posts", "authors", "1"])
    end

    test "static segments with varied size" do
      RouterServer.add_page(:my_site, "1", "/blog/2020/01/07/hello")
      refute RouterServer.lookup_path(:my_site, ["blog", "2020"])
      refute RouterServer.lookup_path(:my_site, ["blog", "2020", "01", "07"])
      refute RouterServer.lookup_path(:my_site, ["blog", "2020", "01", "07", "hello", "extra"])
    end

    test "catch all" do
      RouterServer.add_page(:my_site, "1", "/posts/*slug")

      assert {"/posts/*slug", "1"} = RouterServer.lookup_path(:my_site, ["posts", "2022", "my-post"])
    end

    test "catch all with existing path with same prefix" do
      RouterServer.add_page(:my_site, "1", "/press/releases/*slug")
      RouterServer.add_page(:my_site, "2", "/press/releases")

      assert {"/press/releases/*slug", "1"} = RouterServer.lookup_path(:my_site, ["press", "releases", "announcement"])
      assert {"/press/releases", "2"} = RouterServer.lookup_path(:my_site, ["press", "releases"])
    end

    test "catch all must match at least 1 segment" do
      RouterServer.add_page(:my_site, "1", "/posts/*slug")

      refute RouterServer.lookup_path(:my_site, ["posts"])
    end

    test "mixed dynamic segments" do
      RouterServer.add_page(:my_site, "1", "/posts/:year/*slug")

      assert {"/posts/:year/*slug", "1"} = RouterServer.lookup_path(:my_site, ["posts", "2022", "my-post"])
    end
  end
end
