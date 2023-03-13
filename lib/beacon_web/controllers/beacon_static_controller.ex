# https://github.com/phoenixframework/phoenix_live_dashboard/blob/9140f56c34201237f0feeeff747528eed2795c0c/lib/phoenix/live_dashboard/controllers/assets.ex
defmodule BeaconWeb.BeaconStaticController do
  @moduledoc false

  import Plug.Conn

  def init(asset) when asset in [:css, :js], do: asset

  def call(conn, asset) do
    {content, content_type} = content_and_type(conn.assigns.site, asset)

    # The static files are served for sites and admin,
    # and we need to disable csrf protection because
    # serving script files are forbidden by the CSRFProtection plug.
    conn = put_private(conn, :plug_skip_csrf_protection, true)

    conn
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("cache-control", "public, max-age=31536000")
    |> send_resp(200, content)
    |> halt()
  end

  defp content_and_type(site, :css) do
    {Beacon.RuntimeCSS.fetch(site), "text/css"}
  end

  defp content_and_type(site, :js) do
    {Beacon.RuntimeJS.fetch(site), "text/javascript"}
  end
end
