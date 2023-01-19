# Configure your Beacon repo
config :beacon, Beacon.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "my_app_beacon",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
