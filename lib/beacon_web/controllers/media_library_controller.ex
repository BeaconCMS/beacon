defmodule BeaconWeb.MediaLibraryController do
  use BeaconWeb, :controller

  alias Beacon.MediaLibrary
  alias Beacon.MediaLibrary.Asset

  def show(conn, %{"asset" => asset}) do
    with %{params: %{"site" => site}} <- fetch_query_params(conn),
         %Asset{file_body: file_body, media_type: media_type} <- MediaLibrary.get_asset(site, asset) do
      conn
      |> put_resp_header("content-type", "#{media_type}; charset=utf-8")
      |> send_resp(200, file_body)
    else
      _ -> raise BeaconWeb.NotFoundError, "asset #{inspect(asset)} not found"
    end
  end
end
