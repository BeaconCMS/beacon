defmodule Beacon.BeaconTest.ProxyEndpoint do
  use Beacon.ProxyEndpoint,
    otp_app: :beacon,
    session_options: Application.compile_env!(:beacon, :session_options),
    fallback: Beacon.BeaconTest.Endpoint
end
