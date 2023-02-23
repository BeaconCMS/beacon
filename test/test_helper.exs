Application.put_env(:beacon, Beacon.BeaconTest.Endpoint,
  url: [host: "localhost", port: 4000],
  secret_key_base: "dVxFbSNspBVvkHPN5m6FE6iqNtMnhrmPNw7mO57CJ6beUADllH0ux3nhAI1ic65X",
  live_view: [signing_salt: "ykjYicLHN3EuW0FO"],
  render_errors: [view: Beacon.BeaconTest.ErrorView],
  pubsub_server: Beacon.BeaconTest.PubSub,
  check_origin: false,
  debug_errors: true
)

Mox.defmock(CSSCompilerMock, for: Beacon.RuntimeCSS)

Supervisor.start_link(
  [
    {Phoenix.PubSub, name: Beacon.BeaconTest.PubSub},
    Beacon.BeaconTest.Endpoint,
    {Beacon,
     sites: [
       [
         site: :my_site,
         css_compiler: CSSCompilerMock,
         data_source: Beacon.BeaconTest.BeaconDataSource,
         live_socket_path: "/custom_live"
       ],
       [
         site: :data_source_test,
         css_compiler: CSSCompilerMock,
         data_source: Beacon.BeaconTest.TestDataSource
       ]
     ]}
  ],
  strategy: :one_for_one
)

ExUnit.start(exclude: [:skip])
Ecto.Adapters.SQL.Sandbox.mode(Beacon.Repo, :manual)
