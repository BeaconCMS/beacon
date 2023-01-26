import Config

config :beacon, Beacon.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "beacon_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  ownership_timeout: 1_000_000_000
