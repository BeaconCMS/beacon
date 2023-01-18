defmodule BeaconWeb.MediaLibraryController do
  use BeaconWeb, :controller

  alias Beacon.MediaLibrary
  alias Beacon.MediaLibrary.Asset

  def show(conn, %{"asset" => asset}) do
    %{params: %{"site" => site}} = fetch_query_params(conn)

    %Asset{file_body: file_body, file_type: file_type} = MediaLibrary.get_asset!(site, asset)

    conn
    |> put_resp_header("content-type", "#{file_type}; charset=utf-8")
    |> send_resp(200, file_body)
  end
end
