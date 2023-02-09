defmodule BeaconWeb.BeaconStaticController do
  @moduledoc false

  use BeaconWeb, :controller

  alias Plug.Static

  def call(conn, _params) do
    opts =
      Static.init(
        at: "/beacon_static",
        from: {:beacon, "priv/static"},
        only: ~w(beacon.js beacon.min.js),
        brotli: true,
        gzip: true
      )

    # The static files are served for sites and admin,
    # and we need to disable csrf protection
    # because serving script files are forbidden
    # by the CSRFProtection plug.
    conn = put_private(conn, :plug_skip_csrf_protection, true)

    Static.call(conn, opts)
  end
end
