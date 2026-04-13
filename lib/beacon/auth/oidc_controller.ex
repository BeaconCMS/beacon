defmodule Beacon.Auth.OIDCController do
  @moduledoc """
  Phoenix controller that handles OIDC authentication flows.

  ## Routes

    * `GET /admin/auth/:provider` - Redirects to the provider's authorization URL
    * `GET /admin/auth/:provider/callback` - Handles the provider callback, exchanges
      the authorization code for tokens, and creates a Beacon session

  Provider configuration is read from `Beacon.Auth.Config.providers/0`, which
  returns a keyword list keyed by provider name (atom). Each provider value is
  a map with at least `:discovery_document_uri`, `:client_id`, `:client_secret`,
  `:response_type`, and `:scope`.
  """

  use Phoenix.Controller

  alias Beacon.Auth
  alias Beacon.Auth.Config, as: AuthConfig

  @doc """
  Initiates the OIDC authorization flow by redirecting to the provider.
  """
  def authorize(conn, %{"provider" => provider}) do
    provider_atom = String.to_existing_atom(provider)
    config = provider_config!(provider_atom)
    callback_url = callback_url(conn, provider)

    case OpenIDConnect.authorization_uri(config, callback_url) do
      {:ok, uri} ->
        redirect(conn, external: uri)

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to initiate authentication: #{inspect(reason)}")
        |> redirect(to: "/admin/auth/login")
    end
  end

  @doc """
  Handles the OIDC callback after the user authenticates with the provider.
  """
  def callback(conn, %{"provider" => provider, "code" => code}) do
    provider_atom = String.to_existing_atom(provider)
    config = provider_config!(provider_atom)
    callback_url = callback_url(conn, provider)

    with {:ok, tokens} <- OpenIDConnect.fetch_tokens(config, %{code: code, redirect_uri: callback_url}),
         {:ok, claims} <- OpenIDConnect.verify(config, tokens["id_token"]),
         email when is_binary(email) <- Map.get(claims, "email"),
         {:ok, user} <- Auth.authenticate_oidc(email, provider) do
      {:ok, token} = Auth.create_session(user)

      conn
      |> put_resp_cookie("_beacon_session", Base.url_encode64(token),
        max_age: AuthConfig.session_max_age(),
        http_only: true,
        secure: true,
        same_site: "Lax"
      )
      |> redirect(to: "/admin")
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "No Beacon account found for that email address.")
        |> redirect(to: "/admin/auth/login")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Authentication failed: #{inspect(reason)}")
        |> redirect(to: "/admin/auth/login")

      _ ->
        conn
        |> put_flash(:error, "Authentication failed.")
        |> redirect(to: "/admin/auth/login")
    end
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Missing authorization code.")
    |> redirect(to: "/admin/auth/login")
  end

  defp callback_url(conn, provider) do
    endpoint = Phoenix.Controller.endpoint_module(conn)
    endpoint.url() <> "/admin/auth/#{provider}/callback"
  end

  defp provider_config!(provider_atom) do
    providers = AuthConfig.providers()

    case Keyword.fetch(providers, provider_atom) do
      {:ok, config} when is_map(config) ->
        config

      {:ok, config} when is_list(config) ->
        Map.new(config)

      :error ->
        raise ArgumentError, "OIDC provider #{inspect(provider_atom)} is not configured"
    end
  end
end
