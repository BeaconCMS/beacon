defmodule Mix.Tasks.Beacon.GenSiteTest do
  use Beacon.CodeGenCase
  import Igniter.Test

  @secret_key_base "A0DSgxjGCYZ6fCIrBlg6L+qC/cdoFq5Rmomm53yacVmN95Wcpl57Gv0sTJjKjtIo"
  @signing_salt "O68x1k5B"
  @port 4041
  @secure_port 8445

  @opts_my_site ~w(--site my_site --path /)
  @opts_other_site ~w(--site other --path /other)
  @opts_host ~w(--site my_site --path / --host example.com --port #{@port} --secure-port #{@secure_port} --secret-key-base #{@secret_key_base} --signing-salt #{@signing_salt})

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

  test "host option does not duplicate files and configs" do
    phoenix_project()
    |> Igniter.compose_task("beacon.gen.site", @opts_host)
    |> apply_igniter!()
    |> Igniter.compose_task("beacon.gen.site", @opts_host)
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
      23 + |  scope "/", alias: TestWeb do
      24 + |    pipe_through [:browser, :beacon]
      25 + |    beacon_site "/", site: :my_site
      26 + |  end
      """)
    end

    test "mount another site in router", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> apply_igniter!()
      |> Igniter.compose_task("beacon.gen.site", @opts_other_site)
      |> assert_has_patch("lib/test_web/router.ex", """
      23 23   |  scope "/", alias: TestWeb do
      24 24   |    pipe_through [:browser, :beacon]
         25 + |    beacon_site "/other", site: :other
         26 + |  end
         27 + |
         28 + |  scope "/", alias: TestWeb do
         29 + |    pipe_through [:browser, :beacon]
      25 30   |    beacon_site "/", site: :my_site
      26 31   |  end
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
      2 + |config :beacon, my_site: [site: :my_site, repo: Test.Repo, endpoint: TestWeb.MySiteEndpoint, router: TestWeb.Router]
      """)
    end

    test "add another site config in runtime", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> apply_igniter!()
      |> Igniter.compose_task("beacon.gen.site", @opts_other_site)
      |> assert_has_patch("config/runtime.exs", """
      2     - |config :beacon, my_site: [site: :my_site, repo: Test.Repo, endpoint: TestWeb.MySiteEndpoint, router: TestWeb.Router]
      3   2   |
          3 + |config :beacon,
          4 + |  my_site: [site: :my_site, repo: Test.Repo, endpoint: TestWeb.MySiteEndpoint, router: TestWeb.Router],
          5 + |  other: [site: :other, repo: Test.Repo, endpoint: TestWeb.OtherEndpoint, router: TestWeb.Router]
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
            ...|
       12 12   |      Test.Repo,
       13 13   |      {DNSCluster, query: Application.get_env(:test, :dns_cluster_query) || :ignore},
          14 + |      {Beacon, [sites: [Application.fetch_env!(:beacon, :my_site)]]},
       14 15   |      {Phoenix.PubSub, name: Test.PubSub},
       15 16   |      # Start the Finch HTTP client for sending emails
            ...|
      """)
    end

    test "add another site into existing beacon child", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_my_site)
      |> apply_igniter!()
      |> Igniter.compose_task("beacon.gen.site", @opts_other_site)
      |> assert_has_patch("lib/test/application.ex", """
      14    - |      {Beacon, [sites: [Application.fetch_env!(:beacon, :my_site)]]},
         14 + |      {Beacon, [sites: [Application.fetch_env!(:beacon, :my_site), Application.fetch_env!(:beacon, :other)]]},
      """)
    end
  end

  describe "site endpoint" do
    setup do
      [project: phoenix_project()]
    end

    test "creates endpoint", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_host)
      |> assert_creates("lib/test_web/my_site_endpoint.ex", """
      defmodule TestWeb.MySiteEndpoint do
        use Phoenix.Endpoint, otp_app: :test

        @session_options Application.compile_env!(:test, :session_options)

        def proxy_endpoint, do: TestWeb.ProxyEndpoint

        # socket /live must be in the proxy endpoint

        # Serve at "/" the static files from "priv/static" directory.
        #
        # You should set gzip to true if you are running phx.digest
        # when deploying your static files in production.
        plug Plug.Static,
          at: "/",
          from: :test,
          gzip: false,
          # robots.txt is served by Beacon
          only: ~w(assets fonts images favicon.ico)

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
      |> Igniter.compose_task("beacon.gen.site", @opts_host)
      |> assert_has_patch("config/config.exs", """
         10 + |signing_salt = "#{@signing_salt}"
      """)
      # add config for new endpoint
      |> assert_has_patch("config/config.exs", """
      10 12   |config :test,
         13 + |       TestWeb.MySiteEndpoint,
         14 + |       url: [host: "localhost"],
         15 + |       adapter: Bandit.PhoenixAdapter,
         16 + |       render_errors: [
         17 + |         formats: [html: TestWeb.ErrorHTML, json: TestWeb.ErrorJSON],
         18 + |         layout: false
         19 + |       ],
         20 + |       pubsub_server: Test.PubSub,
         21 + |       live_view: [signing_salt: signing_salt]
         22 + |
      """)
      # update signing salt for host app session_options
      |> assert_has_patch("config/config.exs", """
         31 + |    signing_salt: signing_salt,
      """)
      # update signing salt for existing endpoint
      |> assert_has_patch("config/config.exs", """
         44 + |  live_view: [signing_salt: signing_salt]
      """)
    end

    test "updates dev.exs", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_host)
      |> assert_has_patch("config/dev.exs", """
          2 + |secret_key_base = "#{@secret_key_base}"
      """)
      # add config for new endpoint
      |> assert_has_patch("config/dev.exs", """
          4 + |config :test,
          5 + |       TestWeb.MySiteEndpoint,
          6 + |       http: [ip: {127, 0, 0, 1}, port: 4041],
          7 + |       check_origin: false,
          8 + |       code_reloader: true,
          9 + |       debug_errors: true,
         10 + |       secret_key_base: secret_key_base,
         11 + |       watchers: [
         12 + |         esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
         13 + |         tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
         14 + |       ]
         15 + |
      """)
      # update secret key base for existing endpoint
      |> assert_has_patch("config/dev.exs", """
         36 + |  secret_key_base: secret_key_base,
      """)
    end

    test "updates runtime.exs", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_host)
      # add beacon site config
      |> assert_has_patch("config/runtime.exs", """
         2 + |config :beacon, my_site: [site: :my_site, repo: Test.Repo, endpoint: TestWeb.MySiteEndpoint, router: TestWeb.Router]
      """)
      # configure check_origin for ProxyEndpoint
      |> assert_has_patch("config/runtime.exs", """
        48 + |    check_origin: {TestWeb.ProxyEndpoint, :check_origin, []},
      """)
      # add config for new endpoint
      |> assert_has_patch("config/runtime.exs", """
        54 + |config :test, TestWeb.MySiteEndpoint,
        55 + |  url: [host: "example.com", port: #{@secure_port}, scheme: "https"],
        56 + |  http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: #{@port}],
        57 + |  secret_key_base: secret_key_base,
        58 + |  server: !!System.get_env("PHX_SERVER")
        59 + |
      """)
    end

    test "updates application.ex", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_host)
      |> assert_has_patch("lib/test/application.ex", """
        22 + | TestWeb.MySiteEndpoint,
      """)
    end

    test "updates router", %{project: project} do
      project
      |> Igniter.compose_task("beacon.gen.site", @opts_host)
      |> assert_has_patch("lib/test_web/router.ex", """
        23 + |  scope "/", alias: TestWeb, host: ["localhost", "example.com"] do
        24 + |    pipe_through [:browser, :beacon]
        25 + |    beacon_site "/", site: :my_site
        26 + |  end
        27 + |
      """)
    end
  end

  test "new_endpoint_module!" do
  end
end
