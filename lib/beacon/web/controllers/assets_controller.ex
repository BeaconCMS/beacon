# https://github.com/phoenixframework/phoenix_live_dashboard/blob/9140f56c34201237f0feeeff747528eed2795c0c/lib/phoenix/live_dashboard/controllers/assets.ex
defmodule Beacon.Web.AssetsController do
  @moduledoc false

  import Plug.Conn

  @brotli "br"
  @gzip "gzip"

  def init(asset) when asset in [:css_config, :css, :js], do: asset

  def call(%{assigns: %{site: site}, params: %{"md5" => hash}} = conn, asset) when asset in [:css, :js] when is_binary(hash) do
    accept_encoding =
      case get_req_header(conn, "accept-encoding") do
        [] -> []
        [value] -> Plug.Conn.Utils.list(value)
      end

    content =
      cond do
        @brotli in accept_encoding ->
          Map.put(content_and_type(site, asset, :brotli), :encoding, @brotli)

        @gzip in accept_encoding ->
          Map.put(content_and_type(site, asset, :gzip), :encoding, @gzip)

        :else ->
          content_and_type(site, asset, :deflate)
      end

    # The static files are served for sites,
    # and we need to disable csrf protection because
    # serving script files is forbidden by the CSRFProtection plug.
    conn = put_private(conn, :plug_skip_csrf_protection, true)

    conn
    |> then(fn conn ->
      if content[:encoding] do
        put_resp_header(conn, "content-encoding", content[:encoding])
      else
        conn
      end
    end)
    |> put_resp_header("content-type", content.type)
    |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
    |> send_resp(200, content.body)
    |> halt()
  end

  # TODO: encoding (compress) and caching
  def call(%{assigns: %{site: site}} = conn, :css_config) do
    content = content_and_type(site, :css_config)

    # The static files are served for sites,
    # and we need to disable csrf protection because
    # serving script files is forbidden by the CSRFProtection plug.
    conn = put_private(conn, :plug_skip_csrf_protection, true)

    conn
    |> put_resp_header("content-type", content.type)
    |> put_resp_header("access-control-allow-origin", "*")
    |> send_resp(200, content.body)
    |> halt()
  end

  def call(_conn, asset) do
    raise Beacon.Web.ServerError, "failed to serve asset #{asset}"
  end

  defp content_and_type(site, asset, version \\ :compreseed)

  defp content_and_type(site, :css, version) do
    %{body: Beacon.RuntimeCSS.fetch(site, version), type: "text/css"}
  end

  defp content_and_type(_site, :js, version) do
    %{body: Beacon.RuntimeJS.fetch(version), type: "text/javascript"}
  end

  defp content_and_type(site, :css_config, _version) do
    %{body: Beacon.RuntimeCSS.config(site), type: "text/javascript"}
  end
end
