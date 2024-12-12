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

  @impl Plug
  def init(_opts), do: []

  @impl Plug
  def call(conn, _opts) do
    site =
      case conn do
        %{private: %{phoenix_live_view: {_page_live, _lv_opts, %{extra: %{session: %{"beacon_site" => site}}}}}} -> site
        %{} -> nil
      end

    path_list = conn.path_params["path"]

    case site && path_list && Beacon.RouterServer.lookup_page(site, path_list) do
      nil -> conn
      _page -> Plug.Conn.put_session(conn, "beacon_variant_roll", Enum.random(1..100))
    end
  end
end
