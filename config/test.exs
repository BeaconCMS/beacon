import Config

config :phoenix, :json_library, Jason

config :logger, level: :error

db_port = fn
  "mysql" -> 3306
  "mssql" -> 1433
  _ -> 5432
end

username = fn
  "mysql" -> nil
  "mssql" -> nil
  _ -> "postgres"
end

password = fn
  "mysql" -> nil
  "mssql" -> "Beacon!CMS!!"
  _ -> "postgres"
end

config :beacon, Beacon.Repo,
  database: "beacon_test",
  password: password.(System.get_env("DB_ADAPTER")),
  pool: Ecto.Adapters.SQL.Sandbox,
  username: username.(System.get_env("DB_ADAPTER")),
  ownership_timeout: 1_000_000_000,
  port: db_port.(System.get_env("DB_ADAPTER"))

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
