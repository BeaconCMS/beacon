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

config :beacon, :css_compiler, CSSCompilerMock
