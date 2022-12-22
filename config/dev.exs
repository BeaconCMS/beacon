import Config

config :beacon, Beacon.Repo,
  database: "beacon_dev",
  password: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox,
  username: "postgres",
  ownership_timeout: 1_000_000_000
