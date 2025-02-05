defmodule Beacon.Web.RobotsControllerTest do
  use Beacon.Web.ConnCase, async: false

  test "show", %{conn: conn} do
    conn = get(conn, "/robots.txt")

    assert response(conn, 200) == """
           # http://www.robotstxt.org
           User-agent: *
           Sitemap: http://site_a.com/sitemap.xml
           """

    assert response_content_type(conn, :txt) =~ "charset=utf-8"

    # site: :not_booted
    conn = get(conn, "/other/robots.txt")

    assert response(conn, 200) == """
           # http://www.robotstxt.org
           User-agent: *
           Sitemap: http://site_a.com/other/sitemap.xml
           """

    assert response_content_type(conn, :txt) =~ "charset=utf-8"
  end
end
