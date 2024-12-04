defmodule Beacon.Web.ErrorHTML do
  @moduledoc """
  Render `Beacon.Content.ErrorPage`.
  """

  use Beacon.Web, :html
  require Logger

  @doc false
  def render(<<status_code::binary-size(3), _rest::binary>> = template, %{conn: conn}) do
    {_, _, %{extra: %{session: %{"beacon_site" => site}}}} = conn.private.phoenix_live_view
    error_module = Beacon.Loader.fetch_error_page_module(site)
    conn = Plug.Conn.assign(conn, :beacon, Beacon.Web.BeaconAssigns.new(site))
    Beacon.apply_mfa(site, error_module, :render, [conn, String.to_integer(status_code)])
  rescue
    error ->
      Logger.warning("""
      failed to render error page for #{template}, fallbacking to default Phoenix error page

      Got:

      #{inspect(error)}
      """)

      Phoenix.Controller.status_message_from_template(template)
  end

  def render(template, _assigns) do
    Logger.warning("could not find an error page for #{template}, fallbacking to default Phoenix error page")
    Phoenix.Controller.status_message_from_template(template)
  end
end
