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

    assert response(conn, 200) == """
           <?xml version="1.0" encoding="UTF-8"?>
           <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
             <sitemap>
               <loc>http://localhost:4000/nested/media/sitemap.xml</loc>
             </sitemap><sitemap>
               <loc>http://localhost:4000/nested/site/sitemap.xml</loc>
             </sitemap><sitemap>
               <loc>http://localhost:4000/other/sitemap.xml</loc>
             </sitemap><sitemap>
               <loc>http://localhost:4000/sitemap.xml</loc>
             </sitemap><sitemap>
               <loc>http://site_b.com:4000/sitemap.xml</loc>
             </sitemap>
           </sitemapindex>
           """
  end

  test "show", %{conn: conn, page: page, routes: routes} do
    conn = get(conn, "/sitemap.xml")

    assert response(conn, 200) == """
           <?xml version="1.0" encoding="UTF-8"?>
           <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
               <url>
                   <loc>#{routes.beacon_page_url(conn, page)}</loc>
                   <lastmod>#{DateTime.to_iso8601(page.updated_at)}</lastmod>
               </url>
           </urlset>
           """

    assert response_content_type(conn, :xml) =~ "charset=utf-8"
  end
end
