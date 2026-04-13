defmodule Beacon.Auth.DevLoginController do
  @moduledoc """
  Simple password-based login controller for development mode.

  Only available when `Beacon.Auth.Config.dev_mode?/0` returns `true`.

  ## Route

    * `POST /admin/auth/dev/login` - Authenticates with email and password

  """

  use Phoenix.Controller

  alias Beacon.Auth
  alias Beacon.Auth.Config, as: AuthConfig

  @doc """
  Authenticates a user with email and password (dev mode only).
  """
  def login(conn, %{"email" => email, "password" => password}) do
    unless AuthConfig.dev_mode?() do
      conn
      |> put_status(404)
      |> text("Not found")
      |> halt()
    end

    with user when not is_nil(user) <- Auth.get_user_by_email(email),
         true <- Auth.verify_password(user, password),
         {:ok, token} <- Auth.create_session(user) do
      conn
      |> put_resp_cookie("_beacon_session", Base.url_encode64(token),
        max_age: AuthConfig.session_max_age(),
        http_only: true,
        same_site: "Lax"
      )
      |> redirect(to: "/admin")
    else
      _ ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: "/admin/auth/login")
    end
  end
end
