defmodule Beacon.Web.ErrorHTMLTest do
  use Beacon.Web.ConnCase, async: false
  use Beacon.Test, site: :my_site

  alias Beacon.Web.ErrorHTML

  describe "render/2 unit test" do
    @tag capture_log: true
    test "invalid status code" do
      assert ErrorHTML.render("invalid", %{conn: nil}) == "Internal Server Error"
    end

    @tag capture_log: true
    test "invalid conn" do
      assert ErrorHTML.render("404.html", %{conn: nil}) == "Not Found"
    end
  end

  describe "render/2 integration with dynamic error pages" do
    setup %{conn: conn} do
      beacon_error_page_fixture(
        status: 404,
        template: "My Site Not Found Page"
      )

      conn =
        conn
        |> Plug.Conn.assign(:beacon, %{site: :my_site})
        |> Plug.Conn.put_private(:phoenix_router, Beacon.BeaconTest.Router)

      {:ok, conn: conn}
    end

    test "missing path", %{conn: conn} do
      {404, _headers, body} =
        assert_error_sent(404, fn -> get(conn, "/missing_path") end)

      assert body =~ "My Site Not Found Page"
    end
  end
end
