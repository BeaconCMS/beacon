defmodule Beacon.Web.Controllers.AssetsControllerTest do
  use Beacon.Web.ConnCase, async: true

  setup %{conn: conn} do
    conn =
      conn
      |> Plug.Conn.assign(:beacon, %{site: :my_site})
      |> Plug.Conn.put_private(:phoenix_router, Beacon.BeaconTest.Router)

    path = Beacon.Web.Layouts.asset_path(conn, :js)

    [conn: conn, path: path]
  end

  test "brotli has preference", %{conn: conn, path: path} do
    conn =
      conn
      |> put_req_header("accept-encoding", "deflate, gzip, br")
      |> get(path)

    assert get_resp_header(conn, "content-encoding") == ["br"]
  end

  test "fallback to gzip when brotli is not accepted", %{conn: conn, path: path} do
    conn =
      conn
      |> put_req_header("accept-encoding", "gzip, deflate")
      |> get(path)

    assert get_resp_header(conn, "content-encoding") == ["gzip"]
  end

  test "fallback to deflate when compression is not accepted", %{conn: conn, path: path} do
    conn =
      conn
      |> put_req_header("accept-encoding", "")
      |> get(path)

    assert get_resp_header(conn, "content-encoding") == []
  end
end
