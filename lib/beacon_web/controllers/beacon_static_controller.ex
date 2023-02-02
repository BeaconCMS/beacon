defmodule BeaconWeb.BeaconStaticController do
  @moduledoc false

  use BeaconWeb, :controller

  alias Beacon.Router
  alias Plug.Static

  def call(conn, _params) do
    opts =
      Static.init(
        at: Router.sanitize_path(conn.private.phoenix_router.__beacon_site_prefix__() <> "/beacon_static"),
        from: {:beacon, "priv/static"},
        only: ~w(beacon.js beacon.min.js),
        brotli: true,
        gzip: true
      )

    # beacon_static is served under the beacon_site scope,
    # which is the same used by sites and will have
    # CSRFProtection enabled, but serving static JS
    # is forbidden by Plug.CSRFProtection.
    # disable it because we're serving only files
    # that are generated and controlled by beacon
    conn = put_private(conn, :plug_skip_csrf_protection, true)

    Static.call(conn, opts)
  end
end
