defmodule Beacon.BeaconTest.EndpointSite do
  # The otp app needs to be beacon otherwise Phoenix LiveView will not be
  # able to build the static path since it tries to get from `Application.app_dir`
  # which expects that a real "application" is settled.
  use Phoenix.Endpoint, otp_app: :beacon

  plug Plug.Session, Application.compile_env!(:beacon, :session_options)
  plug Beacon.BeaconTest.Router
end
