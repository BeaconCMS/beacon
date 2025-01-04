# https://github.com/phoenixframework/phoenix_live_dashboard/blob/9140f56c34201237f0feeeff747528eed2795c0c/lib/phoenix/live_dashboard/controllers/assets.ex
defmodule Beacon.Web.AssetsController do
  @moduledoc false

  import Plug.Conn

  def init(asset) when asset in [:css_config, :css, :js], do: asset

  def call(%{params: %{"md5" => hash}} = conn, asset) when is_binary(hash) and asset in [:css, :js] do
    site = site(conn)
    {content, content_type} = content_and_type(site, asset)

    # The static files are served for sites,
    # and we need to disable csrf protection because
    # serving script files is forbidden by the CSRFProtection plug.
    conn = put_private(conn, :plug_skip_csrf_protection, true)

    conn
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
    |> put_resp_header("content-encoding", "br")
    |> send_resp(200, content)
    |> halt()
  end

  # TODO: encoding (compress) and caching
  def call(conn, :css_config) do
    site = site(conn)
    {content, content_type} = content_and_type(site, :css_config)

    # The static files are served for sites,
    # and we need to disable csrf protection because
    # serving script files is forbidden by the CSRFProtection plug.
    conn = put_private(conn, :plug_skip_csrf_protection, true)

    conn
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("access-control-allow-origin", "*")
    |> send_resp(200, content)
    |> halt()
  end

  def call(_conn, asset), do: server_error("failed to serve asset #{asset}")

  defp site(%{assigns: %{site: site}}), do: site
  defp site(_conn), do: server_error("failed to find site to serve assets")

  defp content_and_type(site, :css) do
    content = Beacon.RuntimeCSS.fetch(site) || server_error("empty css content for site #{site}")
    {content, "text/css"}
  end

  defp content_and_type(site, :js) do
    content = Beacon.RuntimeJS.fetch() || server_error("empty js content for site #{site}")
    {content, "text/javascript"}
  end

  defp content_and_type(site, :css_config) do
    content = Beacon.RuntimeCSS.config(site) || server_error("empty css_config for site #{site}")
    {content, "text/javascript"}
  end

  defp server_error(msg), do: raise(Beacon.Web.ServerError, msg)
end
