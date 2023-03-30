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

  def on_mount(%Beacon.Admin.MediaLibrary.Asset{} = context, _params, _session, socket) do
    if Beacon.Authorization.authorized?(socket.assigns.agent, :index, context) do
      {:cont, socket}
    else
      redirect_to = Beacon.Router.beacon_admin_path(socket, "/")
      {:halt, redirect(socket, to: redirect_to)}
    end
  end

  def handle_params(a, b, socket) do
    dbg(a)
    dbg(b)
    {:cont, socket}
  end
end
