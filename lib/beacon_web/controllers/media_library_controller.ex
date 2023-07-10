defmodule BeaconWeb.MediaLibraryController do
  @moduledoc false

  use BeaconWeb, :controller

  alias Beacon.MediaLibrary
  alias Beacon.MediaLibrary.Asset

  def show(conn, %{"file_name" => file_name}) do
    site =
      case conn.path_info do
        ["beacon_assets", site | _] -> String.to_existing_atom(site)
        _ -> nil
      end

    site || raise BeaconWeb.NotFoundError, "failed to serve asset #{file_name}"

    case MediaLibrary.get_asset_by(site, file_name: file_name) do
      %Asset{} = asset ->
        BeaconWeb.Cache.when_stale(conn, asset, fn conn ->
          conn
          |> put_resp_header("content-type", "#{asset.media_type}; charset=utf-8")
          |> BeaconWeb.Cache.asset_cache(:public)
          |> send_resp(200, asset.file_body)
        end)

      _ ->
        raise BeaconWeb.NotFoundError, "asset #{inspect(file_name)} not found"
    end
  end

  def show(_conn, _params) do
    raise BeaconWeb.NotFoundError, "failed to serve asset"
  end
end
