defmodule Mix.Tasks.Beacon.GenProxyEndpointTest do
  use Beacon.CodeGenCase

  import Igniter.Test

  setup do
    [project: phoenix_project()]
  end

  test "do not duplicate files and configs", %{project: project} do
    project
    |> Igniter.compose_task("beacon.gen.proxy_endpoint")
    |> apply_igniter!()
    |> Igniter.compose_task("beacon.gen.proxy_endpoint")
    |> assert_unchanged()
  end

  test "create proxy endpoint module", %{project: project} do
    project
    |> Igniter.compose_task("beacon.gen.proxy_endpoint")
    |> assert_creates("lib/test_web/proxy_endpoint.ex", """
    defmodule TestWeb.ProxyEndpoint do
      use Beacon.ProxyEndpoint,
        otp_app: :test,
        session_options: Application.compile_env!(:test, :session_options),
        fallback: TestWeb.Endpoint
    end
    """)
  end

  test "update config.exs", %{project: project} do
    project
    |> Igniter.compose_task("beacon.gen.proxy_endpoint", signing_salt: "SNUXnTNM")
    # add session options config
    |> assert_has_patch("config/config.exs", """
    10 12   |config :test,
    11 13   |  ecto_repos: [Test.Repo],
    12    - |  generators: [timestamp_type: :utc_datetime]
       14 + |  generators: [timestamp_type: :utc_datetime],
       15 + |  session_options: [
       16 + |    store: :cookie,
       17 + |    key: "_test_key",
       18 + |    signing_salt: "SNUXnTNM",
       19 + |    same_site: "Lax"
       20 + |  ]
    """)
    # add proxy endpoint config
    |> assert_has_patch("config/config.exs", """
       10 + |config :test, TestWeb.ProxyEndpoint, adapter: Bandit.PhoenixAdapter, live_view: [signing_salt: "SNUXnTNM"]
       11 + |
    """)
    # update fallback endpoint signing salt
    |> assert_has_patch("config/config.exs", """
       31 + |  live_view: [signing_salt: "SNUXnTNM"]
    """)
  end

  test "update dev.exs", %{project: project} do
    project
    |> Igniter.compose_task("beacon.gen.proxy_endpoint", signing_salt: "SNUXnTNM")
    |> assert_has_patch("config/dev.exs", """
        3 + |config :test, TestWeb.ProxyEndpoint,
        4 + |  http: [ip: {127, 0, 0, 1}, port: 4000],
        5 + |  check_origin: false,
        6 + |  debug_errors: true,
        7 + |  secret_key_base: "A0DSgxjGCYZ6fCIrBlg6L+qC/cdoFq5Rmomm53yacVmN95Wcpl57Gv0sTJjKjtIp"
        8 + |
    """)
  end

  test "update runtime.exs", %{project: project} do
    project
    |> Igniter.compose_task("beacon.gen.proxy_endpoint", signing_salt: "SNUXnTNM")
    |> assert_has_patch("config/runtime.exs", """
        3 + |config :test, TestWeb.ProxyEndpoint,
        4 + |  check_origin: [],
        5 + |  url: [port: 443, scheme: "https"],
        6 + |  http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
        7 + |  secret_key_base: secret_key_base
        8 + |
    """)
  end
end
