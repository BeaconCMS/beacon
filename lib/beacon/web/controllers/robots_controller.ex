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
    |> render(:robots, sitemap_index_url: get_sitemap_index_url(site))
  end

  defp get_sitemap_index_url(site) do
    routes_module = Beacon.Loader.fetch_routes_module(site)
    Beacon.apply_mfa(site, routes_module, :public_sitemap_index_url, [])
  end
end
