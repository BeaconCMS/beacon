defmodule Beacon.Auth.Config do
  @moduledoc """
  Runtime configuration helpers for Beacon authentication.

  All values are read from `Application.get_env(:beacon, :auth)`.

  ## Example configuration

      config :beacon, :auth,
        dev_mode: true,
        session_signing_salt: "my_salt",
        session_max_age: 86400 * 30,
        providers: [
          google: [
            discovery_document_uri: "https://accounts.google.com/.well-known/openid-configuration",
            client_id: "...",
            client_secret: "...",
            response_type: "code",
            scope: "openid email profile"
          ]
        ]

  """

  @doc "Returns `true` when dev-mode authentication (password login) is enabled."
  def dev_mode? do
    auth_config()[:dev_mode] || false
  end

  @doc "Returns the list of configured OIDC providers."
  def providers do
    auth_config()[:providers] || []
  end

  @doc "Returns the signing salt used for session cookies."
  def session_signing_salt do
    auth_config()[:session_signing_salt] || "beacon_auth"
  end

  @doc "Returns the maximum session age in seconds (default: 30 days)."
  def session_max_age do
    auth_config()[:session_max_age] || 86_400 * 30
  end

  defp auth_config do
    Application.get_env(:beacon, :auth) || []
  end
end
