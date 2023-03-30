defmodule BeaconWeb.Admin.Hooks.AssignAgentTest do
  use BeaconWeb.ConnCase, async: false

  alias Beacon.BeaconTest.Endpoint
  alias Beacon.BeaconTest.Router
  alias BeaconWeb.Admin.Hooks.AssignAgent

  describe "on_mount/4" do
    test "works", %{conn: conn} do
      session =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:session_id, "admin_session_123")
        |> get_session()

      socket = %Phoenix.LiveView.Socket{endpoint: Endpoint, router: Router}
      assert {:cont, %{assigns: %{agent: agent}}} = AssignAgent.on_mount(:default, %{}, session, socket)

      assert %{role: :admin, session_id: "admin_session_123"} = agent
    end
  end
end
