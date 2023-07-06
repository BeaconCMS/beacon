defmodule BeaconWeb.MediaLibraryController do
  @moduledoc false

  use BeaconWeb, :controller

  alias Beacon.MediaLibrary
  alias Beacon.MediaLibrary.Asset

  def show(conn, %{"asset" => asset_name}) do
    with %{params: %{"site" => site}} <- fetch_query_params(conn),
         site = String.to_existing_atom(site),
         %Asset{file_body: file_body, media_type: media_type} = asset <- MediaLibrary.get_asset_by(site, file_name: asset_name) do
      BeaconWeb.Cache.when_stale(conn, asset, fn conn ->
        conn
        |> put_resp_header("content-type", "#{media_type}; charset=utf-8")
        |> BeaconWeb.Cache.asset_cache(:public)
        |> send_resp(200, file_body)
      end)
    else
      _ -> raise BeaconWeb.NotFoundError, "asset #{inspect(asset_name)} not found"
    end
  end
end
