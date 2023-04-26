# Configure your Beacon repo
config :beacon, Beacon.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "<%= app_name %>_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
