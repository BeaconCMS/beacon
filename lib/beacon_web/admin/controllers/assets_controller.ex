# https://github.com/phoenixframework/phoenix_live_dashboard/blob/9140f56c34201237f0feeeff747528eed2795c0c/lib/phoenix/live_dashboard/controllers/assets.ex
defmodule BeaconWeb.Admin.AssetsController do
  @moduledoc false

  import Plug.Conn

  phoenix_js_paths =
    for app <- [:phoenix, :phoenix_html, :phoenix_live_view] do
      path = Application.app_dir(app, ["priv", "static", "#{app}.js"])
      Module.put_attribute(__MODULE__, :external_resource, path)
      path
    end

  js_path = Path.join(__DIR__, "../../../../priv/static/beacon_admin.js")
  @external_resource js_path
  @js """
  #{for path <- phoenix_js_paths, do: path |> File.read!() |> String.replace("//# sourceMappingURL=", "// ")}
  #{File.read!(js_path)}
  """

  css_path = Path.join(__DIR__, "../../../../priv/static/beacon_admin.css")
  @external_resource css_path
  @css File.read!(css_path)

  @hashes %{
    :css => Base.encode16(:crypto.hash(:md5, @css), case: :lower),
    :js => Base.encode16(:crypto.hash(:md5, @js), case: :lower)
  }

  def init(asset) when asset in [:css, :js], do: asset

  def call(conn, asset) do
    {content, content_type} = content_and_type(asset)
    serve(conn, content, content_type)
  end

  defp serve(conn, content, content_type) do
    # The static files are served for admin,
    # and we need to disable csrf protection because
    # serving script files is forbidden by the CSRFProtection plug.
    conn = put_private(conn, :plug_skip_csrf_protection, true)

    conn
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("cache-control", "public, max-age=31536000")
    |> send_resp(200, content)
    |> halt()
  end

  defp content_and_type(:css) do
    {@css, "text/css"}
  end

  defp content_and_type(:js) do
    {@js, "text/javascript"}
  end

  def current_hash(:css), do: @hashes.css
  def current_hash(:js), do: @hashes.js
end
