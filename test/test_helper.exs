Application.put_env(:beacon, Beacon.BeaconTest.Endpoint,
  debug_errors: false,
  render_errors: [view: Beacon.BeaconTest.ErrorView],
  root: Path.expand("..", __DIR__),
  secret_key_base: "dVxFbSNspBVvkHPN5m6FE6iqNtMnhrmPNw7mO57CJ6beUADllH0ux3nhAI1ic65X",
  url: [host: "localhost"],
  live_view: [signing_salt: "ykjYicLHN3EuW0FO"],
  url: [host: "test-app.com"],
  http: [port: 4000],
  server: true
)

Mox.defmock(CSSCompilerMock, for: Beacon.RuntimeCSS)

ExUnit.start()
