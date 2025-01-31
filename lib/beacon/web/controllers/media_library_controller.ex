defmodule Beacon.Web.MediaLibraryController do
  @moduledoc false

  use Beacon.Web, :controller

  alias Beacon.MediaLibrary
  alias Beacon.MediaLibrary.Asset

  def show(%{assigns: %{site: site}} = conn, %{"file_name" => file_name}) when is_atom(site) do
    case MediaLibrary.get_asset_by(site, file_name: file_name) do
      %Asset{} = asset ->
        Beacon.Web.Cache.when_stale(conn, asset, fn conn ->
          conn
          |> put_resp_header("content-type", "#{asset.media_type}; charset=utf-8")
          |> Beacon.Web.Cache.asset_cache(:public)
          |> send_resp(200, asset.file_body)
        end)

      _ ->
        raise Beacon.Web.NotFoundError, "asset #{inspect(file_name)} not found"
    end
  end

  def show(_conn, %{"file_name" => file_name}) do
    raise Beacon.Web.NotFoundError, "failed to serve asset #{file_name}"
  end

  def show(_conn, _params) do
    raise Beacon.Web.NotFoundError, "failed to serve asset"
  end
end
