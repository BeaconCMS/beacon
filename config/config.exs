import Config

config :beacon, ecto_repos: [Beacon.Repo]

config :beacon, :generators, binary_id: true

config :phoenix, :json_library, Jason

if Mix.env() == :dev do
  esbuild = fn args ->
    [
      args: args,
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    ]
  end

  config :esbuild,
    version: "0.17.18",
    cdn: esbuild.(~w(./js/beacon.js --bundle --format=iife --target=es2016 --global-name=Beacon --outfile=../priv/static/beacon.js)),
    cdn_min: esbuild.(~w(./js/beacon.js --bundle --format=iife --target=es2016 --global-name=Beacon --minify --outfile=../priv/static/beacon.min.js)),
    cdn_admin: esbuild.(~w(./js/beacon_admin.js --bundle --format=iife --target=es2016 --global-name=BeaconAdmin --outfile=../priv/static/beacon_admin.js)),
    cdn_min_admin: esbuild.(~w(./js/beacon_admin.js --bundle --format=iife --target=es2016 --global-name=BeaconAdmin --minify --outfile=../priv/static/beacon_admin.min.js))
end

config :tailwind,
  version: "3.2.7",
  admin: [
    args: ~w(
      --config=tailwind.config.admin.js
      --input=css/beacon_admin.css
      --output=../priv/static/beacon_admin.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
