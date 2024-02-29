# https://github.com/phoenixframework/phoenix_live_dashboard/blob/9140f56c34201237f0feeeff747528eed2795c0c/lib/phoenix/live_dashboard/controllers/assets.ex
defmodule BeaconWeb.AssetsController do
  @moduledoc false

  import Plug.Conn

  def init(asset) when asset in [:css, :js], do: asset

  def call(%{assigns: %{site: site}} = conn, asset) do
    {content, content_type} = content_and_type(site, asset)
    serve(conn, content, content_type)
  end

  defp serve(conn, content, content_type) do
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

  defp content_and_type(site, :css) do
    {Beacon.RuntimeCSS.fetch(site), "text/css"}
  end

  defp content_and_type(_site, :js) do
    {Beacon.RuntimeJS.fetch(), "text/javascript"}
  end
end
