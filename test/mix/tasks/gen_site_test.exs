defmodule Mix.Tasks.Beacon.GenSiteTest do
  use Beacon.CodeGenCase
  import Igniter.Test

  @opts_my_site ~w(--site my_site --path /)
  @opts_other_site ~w(--site other --path /other)

  describe "options validation" do
    test "validates site" do
      assert_raise Mix.Error, fn ->
        Igniter.compose_task(test_project(), "beacon.gen.site", ~w(--site nil))
      end

      assert_raise Mix.Error, fn ->
        Igniter.compose_task(test_project(), "beacon.gen.site", ~w(--site beacon_my_site))
      end
    end

    test "validates path" do
      assert_raise Mix.Error, fn ->
        Igniter.compose_task(test_project(), "beacon.gen.site", ~w(--site my_site --path nil))
      end
    end
  end

  test "do not duplicate files and configs" do
    phoenix_project()
    |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
    |> apply_igniter!()
    |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
    |> assert_unchanged()
  end

  describe "migration" do
    setup do
      [project: phoenix_project()]
    end

    test "create initial migration", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> assert_creates("priv/repo/migrations/0_create_beacon_tables.exs", """
      defmodule Test.Repo.Migrations.CreateBeaconTables do
        use Ecto.Migration

        def up, do: Beacon.Migration.up()
        def down, do: Beacon.Migration.down()
      end
      """)
    end
  end

  describe "router" do
    setup do
      project =
        phoenix_project()
        |> Igniter.compose_task("beacon.install", [])
        |> Igniter.Test.apply_igniter!()

      [project: project]
    end

    test "use beacon", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> assert_has_patch("lib/test_web/router.ex", """
      4 + |  use Beacon.Router
      """)
    end

    test "add Beacon.Plug to beacon pipeline", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> assert_has_patch("lib/test_web/router.ex", """
      6 + |  pipeline :beacon do
      7 + |    plug Beacon.Plug
      8 + |  end
      """)
    end

    test "mount site in router", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> assert_has_patch("lib/test_web/router.ex", """
      24 + |    pipe_through [:browser, :beacon]
      25 + |    beacon_site "/", site: :my_site
      """)
    end

    test "mount another site in router", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> apply_igniter!()
      |> Igniter.compose_task("beacon.gen.site", @opts_other_site)
      |> assert_has_patch("lib/test_web/router.ex", """
      24 24   |    pipe_through [:browser, :beacon]
      25 25   |    beacon_site "/", site: :my_site
         26 + |    beacon_site "/other", site: :other
      """)
    end
  end

  describe "config" do
    setup do
      [project: phoenix_project()]
    end

    test "add site config in runtime", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> assert_has_patch("config/runtime.exs", """
      2 + |config :beacon, my_site: [site: :my_site, repo: Test.Repo, endpoint: TestWeb.Endpoint, router: TestWeb.Router]
      """)
    end

    test "add another site config in runtime", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> apply_igniter!()
      |> Igniter.compose_task("beacon.gen.site", @opts_other_site)
      |> assert_has_patch("config/runtime.exs", """
      2     - |config :beacon, my_site: [site: :my_site, repo: Test.Repo, endpoint: TestWeb.Endpoint, router: TestWeb.Router]
      3   2   |
          3 + |config :beacon,
          4 + |  my_site: [site: :my_site, repo: Test.Repo, endpoint: TestWeb.Endpoint, router: TestWeb.Router],
          5 + |  other: [site: :other, repo: Test.Repo, endpoint: TestWeb.Endpoint, router: TestWeb.Router]
      """)
    end
  end

  describe "application" do
    setup do
      [project: phoenix_project()]
    end

    test "add beacon child with site", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> assert_has_patch("lib/test/application.ex", """
      20 + |      TestWeb.Endpoint,
      21 + |      {Beacon, [sites: [Application.fetch_env!(:beacon, :my_site)]]}
      """)
    end

    test "add another site into existing beacon child", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> apply_igniter!()
      |> Igniter.compose_task("beacon.gen.site", @opts_other_site)
      |> assert_has_patch("lib/test/application.ex", """
      21    - |      {Beacon, [sites: [Application.fetch_env!(:beacon, :my_site)]]}
         21 + |      {Beacon, [sites: [Application.fetch_env!(:beacon, :my_site), Application.fetch_env!(:beacon, :other)]]}
      """)
    end
  end

  describe "--host option" do
    setup do
      [project: phoenix_project()]
    end

    test "creates endpoint", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site ++ ~w(--host example.com))
      |> assert_creates("lib/test_web/example_endpoint.ex", """
      defmodule TestWeb.ExampleEndpoint do
        use Phoenix.Endpoint, otp_app: :test

        @session_options Application.compile_env!(:test, :session_options)

        # socket /live must be in the proxy endpoint

        # Serve at "/" the static files from "priv/static" directory.
        #
        # You should set gzip to true if you are running phx.digest
        # when deploying your static files in production.
        plug Plug.Static,
          at: "/",
          from: :test,
          gzip: false,
          only: TestWeb.static_paths()

        # Code reloading can be explicitly enabled under the
        # :code_reloader configuration of your endpoint.
        if code_reloading? do
          socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
          plug Phoenix.LiveReloader
          plug Phoenix.CodeReloader
          plug Phoenix.Ecto.CheckRepoStatus, otp_app: :test
        end

        plug Plug.RequestId
        plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

        plug Plug.Parsers,
          parsers: [:urlencoded, :multipart, :json],
          pass: ["*/*"],
          json_decoder: Phoenix.json_library()

        plug Plug.MethodOverride
        plug Plug.Head
        plug Plug.Session, @session_options
        plug TestWeb.Router
      end
      """)
    end

    test "updates config.exs", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site ++ ~w(--host example.com))
      |> assert_has_patch("config/config.exs", """
         10 + |config :test, TestWeb.ExampleEndpoint,
         11 + |  url: [host: "localhost"],
         12 + |  adapter: Bandit.PhoenixAdapter,
         13 + |  render_errors: [
         14 + |    formats: [html: TestWeb.ErrorHTML, json: TestWeb.ErrorJSON],
         15 + |    layout: false
         16 + |  ],
         17 + |  pubsub_server: Test.PubSub,
         18 + |  live_view: [signing_salt: "O68x1k5A"]
      """)
    end

    test "updates dev.exs", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site ++ ~w(--host example.com))
      |> assert_has_patch("config/dev.exs", """
         3 + |config :test, TestWeb.ExampleEndpoint,
         4 + |  http: [ip: {127, 0, 0, 1}, port: 4002],
         5 + |  check_origin: false,
         6 + |  code_reloader: true,
         7 + |  debug_errors: true,
         8 + |  secret_key_base: "A0DSgxjGCYZ6fCIrBlg6L+qC/cdoFq5Rmomm53yacVmN95Wcpl57Gv0sTJjKjtIp",
         9 + |  watchers: [
        10 + |    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
        11 + |    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
        12 + |  ]
        13 + |
      """)
    end

    test "updates runtime.exs", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site ++ ~w(--host example.com))
      |> assert_has_patch("config/runtime.exs", """
        60 + |config :test, TestWeb.ExampleEndpoint,
        61 + |  url: [host: "example.com", port: 443, scheme: "https"],
        62 + |  http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
        63 + |  secret_key_base: secret_key_base
        64 + |
      """)
      |> assert_has_patch("config/runtime.exs", """
         8 + |config :test, TestWeb.ProxyEndpoint, check_origin: ["example.com"]
      """)
      |> assert_has_patch("config/runtime.exs", """
         9 + |config :beacon, my_site: [site: :my_site, repo: Test.Repo, endpoint: TestWeb.ExampleEndpoint, router: TestWeb.Router]
      """)
    end

    test "updates application.ex", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site ++ ~w(--host example.com))
      |> assert_has_patch("lib/test/application.ex", """
        14 + | TestWeb.ExampleEndpoint,
      """)
    end

    test "updates router", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site ++ ~w(--host example.com))
      |> assert_has_patch("lib/test_web/router.ex", """
        23 + |  scope "/", host: "example.com" do
        24 + |    pipe_through [:browser, :beacon]
        25 + |    beacon_site "/", site: :my_site
        26 + |  end
        27 + |
      """)
    end
  end
end
