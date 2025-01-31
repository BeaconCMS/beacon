import Config

config :phoenix, :json_library, Jason

config :logger, level: :error

config :beacon, ecto_repos: [Beacon.BeaconTest.Repo]

config :tailwind, version: "3.4.4"

config :beacon, Beacon.BeaconTest.Repo,
  url: System.get_env("DATABASE_URL") || "postgres://localhost:5432/beacon_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  priv: "test/support",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

config :beacon,
  session_options: [
    store: :cookie,
    key: "_beacon_test_key",
    signing_salt: "LKBurgGF",
    same_site: "Lax"
  ]

config :beacon, Beacon.BeaconTest.ProxyEndpoint, live_view: [signing_salt: "LKBurgGF"]

config :beacon, Beacon.BeaconTest.Endpoint,
  url: [host: "localhost", port: 4000],
  secret_key_base: "dVxFbSNspBVvkHPN5m6FE6iqNtMnhrmPNw7mO57CJ6beUADllH0ux3nhAI1ic65X",
  live_view: [signing_salt: "LKBurgGF"],
  render_errors: [view: Beacon.BeaconTest.ErrorView],
  pubsub_server: Beacon.BeaconTest.PubSub,
  check_origin: false,
  debug_errors: true

config :beacon, Beacon.BeaconTest.EndpointSite,
  url: [host: "localhost", port: 4000],
  secret_key_base: "dVxFbSNspBVvkHPN5m6FE6iqNtMnhrmPNw7mO57CJ6beUADllH0ux3nhAI1ic65X",
  live_view: [signing_salt: "LKBurgGF"],
  render_errors: [view: Beacon.BeaconTest.ErrorView],
  pubsub_server: Beacon.BeaconTest.PubSub,
  check_origin: false,
  debug_errors: true

# Fake Key Values. We're not putting real creds here.
config :ex_aws,
  access_key_id: "AKIAIOSFODNN7EXAMPLE",
  secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  region: "us-east-1"

config :ex_aws, :s3,
  scheme: "http://",
  host: "localhost",
  port: 5555,
  bucket: "beacon-media-library"
