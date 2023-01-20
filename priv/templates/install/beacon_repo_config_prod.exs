# Configure your Beacon repo
config :beacon, Beacon.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "my_app_beacon",
  pool_size: 10
