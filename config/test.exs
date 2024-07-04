import Config

config :phoenix, :json_library, Jason

config :logger, level: :error

config :beacon, ecto_repos: [Beacon.BeaconTest.Repo]

config :beacon, Beacon.BeaconTest.Repo,
  url: "postgres://localhost:5432/beacon_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  priv: "test/support",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

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
