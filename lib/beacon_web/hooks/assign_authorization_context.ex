defmodule BeaconWeb.Hooks.AssignAuthorizationContext do
  import Phoenix.Component

  alias Beacon.Authorization

  def on_mount(:default, _params, session, socket) do
    authorization_bootstrap = Map.get(session, "authorization_bootstrap", nil)

    requestor_context = Authorization.get_requestor_context(authorization_bootstrap)
    socket = assign(socket, :requestor_context, requestor_context)

    {:cont, socket}
  end
end
