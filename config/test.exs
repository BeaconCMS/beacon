import Config

config :phoenix, :json_library, Jason

config :logger, level: :error

case System.get_env("DB_ADAPTER") do
  "mysql" ->
    config :beacon, Beacon.Repo,
      database: "beacon_test",
      pool: Ecto.Adapters.SQL.Sandbox,
      username: "root",
      ownership_timeout: 1_000_000_000,
      port: 3306,
      protocol: :tcp,
      hostname: "localhost"

  "mssql" ->
    config :beacon, Beacon.Repo,
      database: "beacon_test",
      password: "Beacon!CMS!!",
      pool: Ecto.Adapters.SQL.Sandbox,
      username: "mssql",
      ownership_timeout: 1_000_000_000,
      port: 1433

  _ ->
    config :beacon, Beacon.Repo,
      database: "beacon_test",
      password: "postgres",
      pool: Ecto.Adapters.SQL.Sandbox,
      username: "postgres",
      ownership_timeout: 1_000_000_000
end

config :beacon, ecto_repos: [Beacon.Repo]

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
