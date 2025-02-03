defmodule Beacon.Web.RobotsControllerTest do
  use Beacon.Web.ConnCase, async: false

  test "show", %{conn: conn} do
    conn = get(conn, "/robots.txt")

    assert response(conn, 200) == """
           User-agent: *
           Allow: /

           Sitemap: http://localhost:4000/sitemap.xml
           """

    assert response_content_type(conn, :txt) =~ "charset=utf-8"

    # site: :not_booted
    conn = get(conn, "/other/robots.txt")

    assert response(conn, 200) == """
           User-agent: BadBot
           User-agent: AnotherBot
           Disallow: /

           User-agent: *
           Disallow: /some/path
           Disallow: /another/path
           Allow: /

           Sitemap: http://localhost:4000/other/sitemap.xml
           """

    assert response_content_type(conn, :txt) =~ "charset=utf-8"
  end
end
