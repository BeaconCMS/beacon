defmodule Beacon.BeaconTest.Endpoint do
  # The otp app needs to be beacon otherwise Phoenix LiveView will not be
  # able to build the static path since it tries to get from `Application.app_dir`
  # which expects that a real "application" is settled.
  use Phoenix.Endpoint, otp_app: :beacon

  @session_options [store: :cookie, key: "_beacon_test_key", signing_salt: "LKBurgGF"]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Session, store: :cookie, key: "_beacon_app_key", signing_salt: "5Ude+fet"

  plug Beacon.BeaconTest.Router
end
