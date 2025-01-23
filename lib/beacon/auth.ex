defmodule Beacon.Auth do
  @moduledoc """
  Top-level functions for checking role-based access control.

  These functions are used by Beacon clients such as LiveAdmin, and may be necessary when adding
  customizations to the client.
  """
  import Beacon.Utils, only: [repo: 1]
  import Ecto.Query

  alias Beacon.Auth.Role
  alias Beacon.Config

  @doc """
  Parses the actor's identity from the session.
  """
  @callback actor_from_session(session :: map()) :: actor :: any()

  @doc """
  Checks the role of a given actor.

  Warning: this function should always check for the most recent data, in case it has changed.

  ```elixir
  # bad
  def check_role(actor), do: actor.role
  # good
  def check_role(actor), do: MyApp.Repo.one(from u in Users, where: u.id == ^actor, select: u.role)
  ```
  """
  @callback check_role(actor :: any()) :: role :: any()

  def authorize(site, action, opts) do
    if Keyword.get(opts, :auth, true) do
      do_authorize(site, opts[:actor], action)
    else
      :ok
    end
  end

  defp do_authorize(site, actor, action) do
    role = get_role(site, actor)

    query = from r in Role, where: r.site == ^site, where: r.name == ^to_string(role)

    with %{} = role <- repo(site).one(query),
         true <- to_string(action) in role.capabilities do
      :ok
    else
      _ -> {:error, :not_authorized}
    end
  end

  # defp get_actor(site, session) do
  #   Config.fetch!(site).auth_module.actor_from_session(session)
  # end

  defp get_role(site, actor) do
    Config.fetch!(site).auth_module.check_role(actor)
  end
end
