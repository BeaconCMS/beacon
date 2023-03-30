defmodule BeaconWeb.Admin.Hooks.Authorized do
  @moduledoc false

  import Phoenix.LiveView

  def on_mount({mod, action}, _params, _session, socket) do
    if Beacon.Authorization.authorized?(socket.assigns.agent, action, %{mod: mod}) do
      {:cont, socket}
    else
      redirect_to = Beacon.Router.beacon_admin_path(socket, "/")
      {:halt, redirect(socket, to: redirect_to)}
    end
  end
end
