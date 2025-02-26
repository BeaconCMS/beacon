defmodule Beacon.Web.RobotsControllerTest do
  use Beacon.Web.ConnCase, async: false

  test "show", %{conn: conn} do
    conn = get(%{conn | host: "site_a.com"}, "/robots.txt")

    assert response(conn, 200) == """
           # http://www.robotstxt.org
           User-agent: *
           Sitemap: http://site_a.com/sitemap_index.xml
           """

    assert response_content_type(conn, :txt) =~ "charset=utf-8"
  end
end
