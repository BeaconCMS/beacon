defmodule BeaconWeb.Hooks.AssignAgent do
  @moduledoc """
  Assigns the agent on the socket to be used by `Beacon.Authorization`.

  To enable Authorization you must set a session key/value `authorization_bootstrap`.
  Beacon does not in itself depend on the contents of `authorization_bootstrap`.
  This is to be consumed by your own `Beacon.Authorization` implementation.

  It is presumed you will have already authenticated the agent with your own hook.
  See `Beacon.Router.beacon_admin/2` for details on adding hooks.
  """

  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    socket =
      assign_new(socket, :agent, fn ->
        authorization_bootstrap = Map.get(session, "authorization_bootstrap", nil)
        Beacon.Authorization.get_agent(authorization_bootstrap)
      end)

    {:cont, socket}
  end
end
