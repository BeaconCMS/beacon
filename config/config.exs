import Config

config :beacon, ecto_repos: [Beacon.Repo]

config :beacon, :generators, binary_id: true

config :phoenix, :json_library, Jason

if Mix.env() == :dev do
  esbuild = fn args ->
    [
      args: ~w(./js/beacon.js --bundle) ++ args,
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    ]
  end

  config :esbuild,
    version: "0.17.5",
    cdn: esbuild.(~w(--format=iife --target=es2016 --global-name=Beacon --outfile=../priv/static/beacon.js)),
    cdn_min: esbuild.(~w(--format=iife --target=es2016 --global-name=Beacon --minify --outfile=../priv/static/beacon.min.js))
end

config :tailwind,
  version: "3.2.7",
  admin: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/beacon_admin.css
      --output=../priv/static/beacon_admin.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
