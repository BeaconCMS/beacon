defmodule Beacon.Auth.Plug.RequireRole do
  @moduledoc """
  Plug that enforces role-based authorization.

  Must be used after `Beacon.Auth.Plug.RequireAuth` so that
  `conn.assigns.current_user` is available.

  ## Options

    * `:role` - A single role atom to require (e.g., `:super_admin`)
    * `:roles` - A list of role atoms, any of which satisfies the check
    * `:site` - The site to scope the role check to. Use `:from_params`
      to read it from `conn.params["site"]`

  ## Examples

      # Require super_admin
      plug Beacon.Auth.Plug.RequireRole, role: :super_admin

      # Require site_admin or site_editor, site from URL params
      plug Beacon.Auth.Plug.RequireRole, roles: [:site_admin, :site_editor], site: :from_params

  """

  @behaviour Plug

  import Plug.Conn

  alias Beacon.Auth

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    user = conn.assigns[:current_user]
    roles = roles_from_opts(opts)
    site = site_from_opts(conn, opts)

    if user && authorized?(user, roles, site) do
      conn
    else
      conn
      |> send_resp(403, "Forbidden")
      |> halt()
    end
  end

  defp roles_from_opts(opts) do
    case {Keyword.get(opts, :role), Keyword.get(opts, :roles)} do
      {nil, nil} -> []
      {role, nil} -> [to_string(role)]
      {nil, roles} -> Enum.map(roles, &to_string/1)
      {role, roles} -> [to_string(role) | Enum.map(roles, &to_string/1)]
    end
  end

  defp site_from_opts(conn, opts) do
    case Keyword.get(opts, :site) do
      :from_params -> conn.params["site"]
      site -> site
    end
  end

  defp authorized?(user, roles, site) do
    Enum.any?(roles, fn role ->
      Auth.has_role?(user, role, site)
    end)
  end
end
