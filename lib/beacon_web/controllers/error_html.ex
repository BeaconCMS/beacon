defmodule BeaconWeb.ErrorHTML do
  @moduledoc false

  use BeaconWeb, :html
  require Logger
  alias Beacon.Loader

  def render(<<status_code::binary-size(3), _rest::binary>> = template, %{conn: conn}) do
    {_, _, %{extra: %{session: %{"beacon_site" => site}}}} = conn.private.phoenix_live_view
    error_module = Loader.error_module_for_site(site)
    conn = Plug.Conn.assign(conn, :__site__, site)
    {:safe, error_module.render(conn, String.to_integer(status_code))}
  rescue
    _ ->
      Logger.warning("failed to render error page")
      Phoenix.Controller.status_message_from_template(template)
  end
end
