import Config

config :beacon, ecto_repos: [Beacon.Repo]

config :beacon, :generators, binary_id: true

config :phoenix, :json_library, Jason

db_adapter = fn
  "mysql" -> Ecto.Adapters.MyXQL
  "mssql" -> Ecto.Adapters.Tds
  _ -> Ecto.Adapters.Postgres
end

config :beacon, Beacon.Repo,
  migration_timestamps: [type: :utc_datetime_usec],
  adapter: db_adapter.(System.get_env("DB_ADAPTER"))

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
