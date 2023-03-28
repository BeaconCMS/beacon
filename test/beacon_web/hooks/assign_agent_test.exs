defmodule BeaconWeb.Hooks.AssignAgentTest do
  use BeaconWeb.ConnCase, async: false

  alias BeaconWeb.Hooks.AssignAgent
  alias Beacon.BeaconTest.Endpoint
  alias Beacon.BeaconTest.Router

  describe "on_mount/4" do
    test "works", %{conn: conn} do
      session =
        conn
        |> Plug.Test.init_test_session(%{authorization_bootstrap: %{session_id: "admin_session_123"}})
        |> get_session()

      socket = %Phoenix.LiveView.Socket{endpoint: Endpoint, router: Router}
      assert {:cont, %{assigns: %{agent: agent} }} = AssignAgent.on_mount(:default, %{}, session, socket)

      assert %{role: :admin, session_id: "admin_session_123"} = agent
    end
  end
end
