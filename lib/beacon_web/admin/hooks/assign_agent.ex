defmodule BeaconWeb.Admin.Hooks.AssignAgent do
  @moduledoc """
  Assigns the agent on the socket to be used by `Beacon.Authorization`.

  It is presumed you will have already authenticated the agent with your own hook.
  See `Beacon.Router.beacon_admin/2` for details on adding hooks.
  """

  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    socket =
      assign_new(socket, :agent, fn ->
        Beacon.Authorization.get_agent(session)
      end)

    {:cont, socket}
  end
end
