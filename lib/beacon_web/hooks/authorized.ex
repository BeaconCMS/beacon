defmodule BeaconWeb.Hooks.Authorized do
  @moduledoc false

  import Phoenix.LiveView

  @redirect_to "/"

  def on_mount(%Beacon.Admin.MediaLibrary.Asset{} = context, _params, _session, socket) do
    if Beacon.Authorization.authorized?(socket.assigns.agent, :index, context) do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: @redirect_to)}
    end
  end

  def on_mount(%Beacon.Pages.Page{} = context, _params, _session, socket) do
    if Beacon.Authorization.authorized?(socket.assigns.agent, :index, context) do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: @redirect_to)}
    end
  end
end
