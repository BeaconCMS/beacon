defmodule BeaconWeb.Live.Admin.PageLive.IndexTest do
  use BeaconWeb.ConnCase, async: true

  import Beacon.Fixtures

  describe "authorization" do
    test "Admin can both create and edit pages", %{conn: conn} do
      page_fixture(path: "blog_a", order: 0)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:authorization_bootstrap, %{session_id: "admin_session_123"})

      assert {:ok, _view, html} = live(conn, "/admin/pages")
      assert html =~ "New Page"
      assert html =~ "Edit"
    end

    test "Editor cannot create a new page, but can edit an existing one", %{conn: conn} do
      page_fixture(path: "blog_a", order: 0)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:authorization_bootstrap, %{session_id: "editor_session_123"})

      assert {:ok, _view, html} = live(conn, "/admin/pages")
      refute html =~ "New Page"
      assert html =~ "Edit"
    end

    test "Some other role is redirected when not allowed to view index", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:authorization_bootstrap, %{session_id: "other_session_123"})

      assert {:error, {:redirect, %{flash: %{}, to: "/admin"}}} = live(conn, "/admin/pages")
    end
  end
end
