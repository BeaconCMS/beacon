import Config

config :phoenix, :json_library, Jason

config :logger, level: :error

config :beacon, Beacon.Repo,
  database: "beacon_test",
  password: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox,
  username: "postgres",
  ownership_timeout: 1_000_000_000

config :beacon, ecto_repos: [Beacon.Repo]

config :ex_aws,
  access_key_id: "AKIAIOSFODNN7EXAMPLE",
  secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  region: "us-east-1"

config :ex_aws, :s3,
  scheme: "http://",
  host: "localhost",
  port: 5555,
  bucket: "beacon-media-library"
