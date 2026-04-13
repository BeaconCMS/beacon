defmodule Beacon.Web.SitemapController do
  @moduledoc false
  use Beacon.Web, :controller

  def init(action) when action in [:show], do: action

  def call(%{assigns: %{site: site}} = conn, :show) do
    conn
    |> accepts(["xml"])
    |> put_view(Beacon.Web.SitemapXML)
    |> put_resp_content_type("text/xml")
    |> put_resp_header("cache-control", "public max-age=300")
    |> render(:sitemap, pages: get_pages(site))
  end

  defp get_pages(site) do
    site
    |> Beacon.Content.list_published_pages()
    |> Enum.reject(fn page ->
      extra = page.extra || %{}
      extra["sitemap_exclude"] == true or extra["sitemap_exclude"] == "true"
    end)
    |> Enum.map(fn page ->
      extra = page.extra || %{}

      %{
        loc: Beacon.RuntimeRenderer.public_page_url(site, page),
        lastmod: DateTime.to_iso8601(page.date_modified || page.updated_at),
        changefreq: extra["sitemap_changefreq"],
        priority: extra["sitemap_priority"]
      }
    end)
  end
end
