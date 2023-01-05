import Config

config :beacon, ecto_repos: [Beacon.Repo]

config :beacon, :generators, binary_id: true

config :phoenix, :json_library, Jason

config :esbuild,
  version: "0.16.13",
  default: [
    args: ~w(js/app.js --bundle --target=es2020 --outdir=../dist/js),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
