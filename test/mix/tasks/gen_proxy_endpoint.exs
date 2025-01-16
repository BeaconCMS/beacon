defmodule Mix.Tasks.Beacon.GenProxyEndpointTest do
  use Beacon.CodeGenCase

  import Igniter.Test

  @signing_salt "SNUXnTNM"
  @secret_key_base "A0DSgxjGCYZ6fCIrBlg6L+qC/cdoFq5Rmomm53yacVmN95Wcpl57Gv0sTJjKjtIp"

  @opts ~w(--signing-salt #{@signing_salt} --secret-key-base #{@secret_key_base})

  setup do
    [project: phoenix_project()]
  end

  test "do not duplicate files and configs", %{project: project} do
    project
    |> Igniter.compose_task("beacon.gen.proxy_endpoint", @opts)
    |> apply_igniter!()
    |> Igniter.compose_task("beacon.gen.proxy_endpoint", @opts)
    |> assert_unchanged()
  end

  test "create proxy endpoint module", %{project: project} do
    project
    |> Igniter.compose_task("beacon.gen.proxy_endpoint", @opts)
    |> assert_creates("lib/test_web/proxy_endpoint.ex", """
    defmodule TestWeb.ProxyEndpoint do
      use Beacon.ProxyEndpoint,
        otp_app: :test,
        session_options: Application.compile_env!(:test, :session_options),
        fallback: TestWeb.Endpoint
    end
    """)
  end

  test "add endpoint to application.ex", %{project: project} do
    project
    |> Igniter.compose_task("beacon.gen.proxy_endpoint", @opts)
    |> assert_has_patch("lib/test/application.ex", """
    20    - |      TestWeb.Endpoint
       20 + |      TestWeb.Endpoint,
       21 + |      TestWeb.ProxyEndpoint
    """)
  end

  test "update config.exs", %{project: project} do
    project
    |> Igniter.compose_task("beacon.gen.proxy_endpoint", @opts)
    # add session options config
    |> assert_has_patch("config/config.exs", """
    10 12   |config :test,
    11 13   |  ecto_repos: [Test.Repo],
    12    - |  generators: [timestamp_type: :utc_datetime]
       14 + |  generators: [timestamp_type: :utc_datetime],
       15 + |  session_options: [
       16 + |    store: :cookie,
       17 + |    key: "_test_key",
       18 + |    signing_salt: "#{@signing_salt}",
       19 + |    same_site: "Lax"
       20 + |  ]
    """)
    # add proxy endpoint config
    |> assert_has_patch("config/config.exs", """
       10 + |config :test, TestWeb.ProxyEndpoint, adapter: Bandit.PhoenixAdapter, live_view: [signing_salt: "#{@signing_salt}"]
       11 + |
    """)
    # update fallback endpoint signing salt
    |> assert_has_patch("config/config.exs", """
       31 + |  live_view: [signing_salt: "#{@signing_salt}"]
    """)
  end

  test "update dev.exs", %{project: project} do
    project
    |> Igniter.compose_task("beacon.gen.proxy_endpoint", @opts)
    |> assert_has_patch("config/dev.exs", """
        3 + |config :test, TestWeb.ProxyEndpoint,
        4 + |  http: [ip: {127, 0, 0, 1}, port: 4000],
        5 + |  check_origin: false,
        6 + |  debug_errors: true,
        7 + |  secret_key_base: "#{@secret_key_base}"
        8 + |
    """)
    |> assert_has_patch("config/dev.exs", """
    12    - |  http: [ip: {127, 0, 0, 1}, port: 4000],
       18 + |  http: [ip: {127, 0, 0, 1}, port: 4100],
    """)
  end

  test "update runtime.exs", %{project: project} do
    project
    |> Igniter.compose_task("beacon.gen.proxy_endpoint", @opts)
    |> assert_has_patch("config/runtime.exs", """
       46 + |config :test, TestWeb.ProxyEndpoint,
       47 + |  check_origin: [],
       48 + |  url: [port: 443, scheme: "https"],
       49 + |  http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
       50 + |  secret_key_base: secret_key_base
       51 + |
    """)
    |> assert_has_patch("config/runtime.exs", """
    41  41   |  config :test, TestWeb.Endpoint,
    42     - |    url: [host: host, port: 8443, scheme: "https"],
    43     - |    http: [
    44     - |      # Enable IPv6 and bind on all interfaces.
    45     - |      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
    46     - |      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
    47     - |      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
    48     - |      ip: {0, 0, 0, 0, 0, 0, 0, 0},
    49     - |      port: port
    50     - |    ],
        42 + |    url: [host: host, port: 8443, scheme: "https"],
        43 + |    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: 4100],
    51  44   |    secret_key_base: secret_key_base
    """)
  end
end
