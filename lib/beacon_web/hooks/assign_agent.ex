defmodule BeaconWeb.Hooks.AssignAgent do
  import Phoenix.Component

  alias Beacon.Authorization

  def on_mount(:default, _params, session, socket) do
    authorization_bootstrap = Map.get(session, "authorization_bootstrap", nil)

    agent = Authorization.get_agent(authorization_bootstrap)
    socket = assign(socket, :agent, agent)

    {:cont, socket}
  end
end
