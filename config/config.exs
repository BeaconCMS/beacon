import Config

config :beacon, ecto_repos: [Beacon.Repo]

config :beacon, :generators, binary_id: true

config :beacon, :reload_modules?, true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
