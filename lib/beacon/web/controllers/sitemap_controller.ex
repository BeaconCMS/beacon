defmodule Beacon.Web.SitemapController do
  @moduledoc false
  use Beacon.Web, :controller

  def init(action) when action in [:index, :show], do: action

  def call(%{assigns: %{sites: sites}} = conn, :index) do
    conn
    |> put_view(Beacon.Web.SitemapXML)
    |> put_resp_content_type("text/xml")
    # may need to adjust caching
    |> put_resp_header("cache-control", "public max-age=300")
    |> render(:sitemap_index, urls: Enum.map(sites, &url_for/1))
  end

  def call(%{assigns: %{site: site}} = conn, :show) do
    conn
    |> put_view(Beacon.Web.SitemapXML)
    |> put_resp_content_type("text/xml")
    # may need to adjust caching
    |> put_resp_header("cache-control", "public max-age=300")
    |> render(:sitemap, pages: get_pages(site))
  end

  defp url_for({site, _path}) do
    routes_module = Beacon.Loader.fetch_routes_module(site)

    Beacon.apply_mfa(site, routes_module, :beacon_sitemap_url, [])
  end

  defp get_pages(site) do
    routes_module = Beacon.Loader.fetch_routes_module(site)

    site
    |> Beacon.Content.list_published_pages()
    |> Enum.map(fn page ->
      %{
        loc: Beacon.apply_mfa(site, routes_module, :beacon_page_url, [page]),
        lastmod: page.updated_at
      }
    end)
  end
end
