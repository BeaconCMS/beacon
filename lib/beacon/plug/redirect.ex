defmodule Beacon.Plug.Redirect do
  @moduledoc """
  Plug that checks incoming requests against cached redirect rules.

  Inserted in the proxy endpoint pipeline before routing. Uses ETS for
  constant-time exact-match lookups. Regex patterns are checked in
  priority order as a fallback.

  Hit counts are incremented asynchronously to avoid slowing the redirect.
  """

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%{method: method} = conn, _opts) when method in ["GET", "HEAD"] do
    path = "/" <> Enum.join(conn.path_info, "/")

    case find_redirect(path) do
      {destination, status_code, site} ->
        # Increment hit count asynchronously
        Task.start(fn -> Beacon.Content.increment_redirect_hit(site, path) end)

        # Preserve query string
        destination =
          case conn.query_string do
            "" -> destination
            qs -> "#{destination}?#{qs}"
          end

        conn
        |> Plug.Conn.put_resp_header("location", destination)
        |> Plug.Conn.send_resp(status_code, "")
        |> Plug.Conn.halt()

      nil ->
        conn
    end
  end

  def call(conn, _opts), do: conn

  defp find_redirect(path) do
    Beacon.Registry.running_sites()
    |> Enum.find_value(fn site ->
      case Beacon.Content.RedirectCache.lookup(site, path) do
        {dest, status} -> {dest, status, site}
        nil -> nil
      end
    end)
  end
end
