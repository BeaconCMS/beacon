defmodule Beacon.Plug do
  @moduledoc """
  Used to ensure consistency for Beacon Page rendering.

  This is especially important when using Page Variants.

  ## Usage

  Add the plug to your Router's `:browser` pipeline:

  ```
  pipeline :browser do
    ...
    plug Beacon.Plug
  end
  ```
  """
  @behaviour Plug

  @private_routes [
    "__beacon_check__",
    "__beacon_assets__",
    "__beacon_media__"
  ]

  @impl Plug
  def init(_opts), do: []

  @impl Plug
  def call(conn, _opts) do
    if Enum.any?(@private_routes, &(&1 in conn.path_info)) do
      conn
    else
      put_roll(conn)
    end
  end

  defp put_roll(conn) do
    path_list = conn.path_params["path"]

    with %{private: %{phoenix_live_view: {_, _, %{extra: %{session: site_session}}}}} <- conn,
         site <- fetch_session_site(site_session),
         {_, _} <- Beacon.RouterServer.lookup_path(site, path_list, 1) do
      Plug.Conn.put_session(conn, "beacon_variant_roll", Enum.random(1..100))
    else
      _ -> conn
    end
  end

  defp fetch_session_site(site_session) do
    case site_session do
      {Beacon.Router, :session, [site, _]} -> site
      %{"beacon_site" => site} -> site
    end
  end
end
