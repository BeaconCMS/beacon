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

config :beacon, otp_app: :beacon

config :beacon, Beacon,
  sites: [
    my_site: [data_source: Beacon.BeaconTest.BeaconDataSource, live_socket_path: "/custom_live"],
    data_source_test: [data_source: Beacon.BeaconTest.TestDataSource]
  ]
