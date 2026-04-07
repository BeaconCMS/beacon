defmodule Beacon.Web.ErrorHTML do
  @moduledoc """
  Render `Beacon.Content.ErrorPage`.
  """

  use Beacon.Web, :html
  require Logger

  @doc false
  def render(<<status_code::binary-size(3), _rest::binary>> = template, %{conn: conn}) do
    case conn.private do
      %{phoenix_live_view: {_, _, %{extra: %{session: %{"beacon_site" => site}}}}} ->
        status = String.to_integer(status_code)
        assigns = %{conn: conn, beacon: %{site: site}}

        case Beacon.RuntimeRenderer.render_error_page(site, status, assigns) do
          {:ok, rendered} ->
            rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()

          {:error, :not_found} ->
            Phoenix.Controller.status_message_from_template(template)
        end

      _ ->
        Phoenix.Controller.status_message_from_template(template)
    end
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
