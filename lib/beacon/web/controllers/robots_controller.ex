defmodule Beacon.Web.RobotsController do
  @moduledoc false
  use Beacon.Web, :controller

  def init(:show), do: :show

  def call(%{assigns: %{site: site}} = conn, :show) do
    conn
    |> accepts(["txt"])
    |> put_view(Beacon.Web.RobotsTxt)
    |> put_resp_content_type("text/txt")
    |> put_resp_header("cache-control", "public max-age=300")
    |> render(:robots, sitemap_url: get_sitemap_url(conn, site))
  end

  defp get_sitemap_url(conn, site) do
    routes_module = Beacon.Loader.fetch_routes_module(site)
    Beacon.apply_mfa(site, routes_module, :beacon_sitemap_url, [conn])
  end
end
