import Config

config :beacon, ecto_repos: [Beacon.BeaconTest.Repo]

config :beacon, :generators, binary_id: true

config :phoenix, :json_library, Jason

config :beacon, Beacon.BeaconTest.Repo,
  migration_lock: false,
  name: Beacon.BeaconTest.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  priv: "priv/repo",
  stacktrace: true,
  migration_timestamps: [type: :utc_datetime_usec],
  url: System.get_env("DATABASE_URL") || "postgres://localhost:5432/beacon_test"

if Mix.env() == :dev do
  esbuild = fn args ->
    [
      args: ~w(./js/beacon.js --bundle) ++ args,
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    ]
  end

  config :esbuild,
    version: "0.17.18",
    cdn: esbuild.(~w(--format=iife --target=es2016 --global-name=Beacon --outfile=../priv/static/beacon.js)),
    cdn_min: esbuild.(~w(--format=iife --target=es2016 --global-name=Beacon --minify --outfile=../priv/static/beacon.min.js))
end

import_config "#{config_env()}.exs"
