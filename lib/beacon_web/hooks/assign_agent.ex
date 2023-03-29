defmodule BeaconWeb.Hooks.AssignAgent do
  @moduledoc """
    Assigns the agent on the socket to be used by `Beacon.Authorization`.

    To enable Authorization you must set a session key `authorization_bootstrap` with a value that will be consumed by `Beacon.Authorization`.
    It is presumed you will have already authenticated the agent with your own hook.
    See `Beacon.Router.beacon_admin/2` for details on adding hooks.

  """
  import Phoenix.Component

  alias Beacon.Authorization

  def on_mount(:default, _params, session, socket) do
    authorization_bootstrap = Map.get(session, "authorization_bootstrap", nil)

    agent = Authorization.get_agent(authorization_bootstrap)
    socket = assign(socket, :agent, agent)

    {:cont, socket}
  end
end
