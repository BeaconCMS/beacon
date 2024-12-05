defmodule Beacon.Web.SitemapControllerTest do
  use Beacon.Web.ConnCase, async: false

  setup do
    site = :my_site

    layout =
      beacon_published_layout_fixture(
        site: site,
        template: """
        <header>Page header</header>
        <%= @inner_content %>
        <footer>Page footer</footer>
        """
      )

    page = beacon_published_page_fixture(site: site, path: "/foo", layout_id: layout.id)

    routes = Beacon.Loader.fetch_routes_module(site)

    [site: site, layout: layout, page: page, routes: routes]
  end

  test "index", %{conn: conn} do
    conn = get(conn, "/sitemap_index.xml")

    assert response(conn, 200) =~ "/other"
  end

  test "show", %{conn: conn, page: page, routes: routes} do
    conn = get(conn, "/sitemap.xml")

    assert response(conn, 200) == """
           &lt;?xml version=&quot;1.0&quot; encoding=&quot;UTF-8&quot;?&gt;
           &lt;urlset xmlns=&quot;http://www.sitemaps.org/schemas/sitemap/0.9&quot;&gt;
               &lt;url&gt;
                   &lt;loc&gt;#{routes.beacon_page_url(page)}&lt;/loc&gt;
                   &lt;lastmod&gt;#{DateTime.to_string(page.updated_at)}&lt;/lastmod&gt;
               &lt;/url&gt;
           &lt;/urlset&gt;
           """

    assert response_content_type(conn, :xml) =~ "charset=utf-8"
  end
end
