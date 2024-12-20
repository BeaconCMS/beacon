defmodule Beacon.Web.CheckController do
  @moduledoc false
  # TODO: replace CheckController with a plug in https://github.com/BeaconCMS/beacon/pull/694

  import Plug.Conn

  def init(conn), do: conn

  def call(conn, _) do
    conn
    |> put_resp_header("content-type", "text/plain")
    |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
    |> send_resp(200, "")
    |> halt()
  end
end
