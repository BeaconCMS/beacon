defmodule Beacon.Auth.Plug.RequireAuth do
  @moduledoc """
  Plug that enforces authentication by reading the Beacon session cookie.

  If a valid session token is found in `_beacon_session`, the corresponding
  user is loaded and assigned to `conn.assigns.current_user`. Otherwise
  the connection is redirected to the login page and halted.

  ## Usage

      plug Beacon.Auth.Plug.RequireAuth

  """

  @behaviour Plug

  import Plug.Conn

  alias Beacon.Auth

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    with cookie when is_binary(cookie) <- conn.cookies["_beacon_session"],
         {:ok, token} <- Base.url_decode64(cookie),
         %{} = user <- Auth.get_user_by_session_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> Phoenix.Controller.redirect(to: "/admin/auth/login")
        |> halt()
    end
  end
end
