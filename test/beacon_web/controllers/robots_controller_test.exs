defmodule Beacon.Web.RobotsControllerTest do
  use Beacon.Web.ConnCase, async: false

  test "show", %{conn: conn} do
    conn = get(%{conn | host: "site_a.com"}, "/robots.txt")
    body = response(conn, 200)

    # Verify structure: AI crawler directives + default rules + sitemap
    assert body =~ "# http://www.robotstxt.org"
    assert body =~ "User-agent: *\nAllow: /"
    assert body =~ "Sitemap: http://site_a.com/sitemap_index.xml"

    # Default policy is :allow_search — training bots blocked, search bots allowed
    assert body =~ "User-agent: GPTBot\nDisallow: /"
    assert body =~ "User-agent: anthropic-ai\nDisallow: /"
    assert body =~ "User-agent: OAI-SearchBot\nAllow: /"
    assert body =~ "User-agent: PerplexityBot\nAllow: /"

    assert response_content_type(conn, :txt) =~ "charset=utf-8"
  end
end
