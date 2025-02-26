defmodule Beacon.Web.SitemapControllerTest do
  use Beacon.Web.ConnCase, async: false
  use Beacon.Test, site: :my_site

  setup %{conn: conn} do
    [
      conn: %{conn | host: "site_a.com"},
      page: beacon_published_page_fixture(site: default_site(), path: "/foo")
    ]
  end

  describe "sitemap_index" do
    test "only includes sitemap of sites in the same host", %{conn: conn} do
      conn = get(conn, "/sitemap_index.xml")

      assert response(conn, 200) == """
             <?xml version="1.0" encoding="UTF-8"?>
             <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
               <sitemap>
                 <loc>http://site_a.com/nested/media/sitemap.xml</loc>
               </sitemap>
               <sitemap>
                 <loc>http://site_a.com/nested/site/sitemap.xml</loc>
               </sitemap>
               <sitemap>
                 <loc>http://site_a.com/other/sitemap.xml</loc>
               </sitemap>
               <sitemap>
                 <loc>http://site_a.com/sitemap.xml</loc>
               </sitemap>
             </sitemapindex>
             """
    end

    test "empty when no sites found", %{conn: conn} do
      conn = get(%{conn | host: "other.com"}, "/sitemap_index.xml")

      assert response(conn, 200) == """
             <?xml version="1.0" encoding="UTF-8"?>
             <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
             </sitemapindex>
             """
    end
  end

  test "show", %{conn: conn, page: page} do
    conn = get(conn, "/sitemap.xml")

    assert response(conn, 200) == """
           <?xml version="1.0" encoding="UTF-8"?>
           <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
             <url>
               <loc>http://site_a.com/foo</loc>
               <lastmod>#{DateTime.to_iso8601(page.updated_at)}</lastmod>
             </url>
           </urlset>
           """

    assert response_content_type(conn, :xml) =~ "charset=utf-8"
  end
end
