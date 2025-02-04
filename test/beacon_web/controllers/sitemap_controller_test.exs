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

    [site: site, layout: layout, page: page]
  end

  test "index only includes sitemap of mounted sites", %{conn: conn} do
    conn = get(conn, "/sitemap_index.xml")

    assert response(conn, 200) == """
           <?xml version="1.0" encoding="UTF-8"?>
           <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
             <sitemap>
               <loc>http://localhost/nested/media/sitemap.xml</loc>
             </sitemap>
             <sitemap>
               <loc>http://localhost/nested/site/sitemap.xml</loc>
             </sitemap>
             <sitemap>
               <loc>http://localhost/other/sitemap.xml</loc>
             </sitemap>
             <sitemap>
               <loc>http://localhost/sitemap.xml</loc>
             </sitemap>
             <sitemap>
               <loc>http://site_b.com/sitemap.xml</loc>
             </sitemap>
           </sitemapindex>
           """
  end

  test "show", %{conn: conn, page: page} do
    conn = get(conn, "/sitemap.xml")

    assert response(conn, 200) == """
           <?xml version="1.0" encoding="UTF-8"?>
           <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
               <url>
                   <loc>http://localhost/foo</loc>
                   <lastmod>#{DateTime.to_iso8601(page.updated_at)}</lastmod>
               </url>
           </urlset>
           """

    assert response_content_type(conn, :xml) =~ "charset=utf-8"
  end
end
