defmodule Beacon.BeaconTest.ProxyEndpoint do
  use Beacon.ProxyEndpoint,
    otp_app: :beacon,
    session_options: Application.compile_env!(:beacon, :session_options),
    fallback: Beacon.BeaconTest.Endpoint
end

defmodule Beacon.BeaconTest.Endpoint do
  # The otp app needs to be beacon otherwise Phoenix LiveView will not be
  # able to build the static path since it tries to get from `Application.app_dir`
  # which expects that a real "application" is settled.
  use Phoenix.Endpoint, otp_app: :beacon

  def proxy_endpoint, do: Beacon.BeaconTest.ProxyEndpoint

  plug Plug.Session, Application.compile_env!(:beacon, :session_options)
  plug Beacon.BeaconTest.Router
end

defmodule Beacon.BeaconTest.EndpointB do
  # The otp app needs to be beacon otherwise Phoenix LiveView will not be
  # able to build the static path since it tries to get from `Application.app_dir`
  # which expects that a real "application" is settled.
  use Phoenix.Endpoint, otp_app: :beacon

  def proxy_endpoint, do: Beacon.BeaconTest.ProxyEndpoint

  plug Plug.Session, Application.compile_env!(:beacon, :session_options)
  plug Beacon.BeaconTest.Router
end
