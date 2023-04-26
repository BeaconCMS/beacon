# Configure your Beacon repo
config :beacon, Beacon.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "<%= app_name %>",
  pool_size: 10
