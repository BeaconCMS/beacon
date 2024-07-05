import Config

config :beacon, :generators, binary_id: true

config :phoenix, :json_library, Jason

if Mix.env() == :dev do
  min_esbuild = fn args ->
    [
      args: args,
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    ]
  end

  esbuild = fn args ->
    min_esbuild.(~w(./js/beacon.js --bundle) ++ args)
  end

  config :esbuild,
    version: "0.17.18",
    cdn: esbuild.(~w(--format=iife --target=es2016 --global-name=Beacon --outfile=../priv/static/beacon.js)),
    cdn_min: esbuild.(~w(--format=iife --target=es2016 --global-name=Beacon --minify --outfile=../priv/static/beacon.min.js)),
    tailwind: min_esbuild.(~w(./tailwind.base.config.js --bundle --format=esm --target=es2016 --minify --outfile=../priv/static/tailwind.config.js))
end

if config_env() == :test, do: import_config("test.exs")
