defmodule BeaconWeb.BeaconAssignsTest do
  use ExUnit.Case, async: true
  alias BeaconWeb.BeaconAssigns

  setup do
    [socket: %Phoenix.LiveView.Socket{assigns: %{__changed__: %{beacon: true}, beacon: %BeaconAssigns{}}}]
  end

  test "update/3", %{socket: socket} do
    assert %{assigns: %{beacon: %BeaconAssigns{site: "one"}}} = BeaconAssigns.update(socket, :site, "one")
    assert %{assigns: %{beacon: %BeaconAssigns{site: "two"}}} = BeaconAssigns.update(socket, :site, "two")
  end

  test "update_private/3", %{socket: socket} do
    assert %{assigns: %{beacon: %BeaconAssigns{private: %{page_id: 1}}}} = BeaconAssigns.update_private(socket, :page_id, 1)
    assert %{assigns: %{beacon: %BeaconAssigns{private: %{page_id: 2}}}} = BeaconAssigns.update_private(socket, :page_id, 2)
  end
end
