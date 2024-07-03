Code.require_file("../../support/mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Beacon.InstallTest do
  use ExUnit.Case

  import Beacon.MixHelper

  alias Mix.Tasks.Beacon.Install

  @config_path "config/config.exs"
  @dev_path "config/dev.exs"
  @application_path "lib/my_app/application.ex"
  @router_path "lib/my_app_web/router.ex"
  @mixfile_path "mix.exs"

  setup do
    create_sample_project()
    on_exit(&clean_tmp_dir/0)
    :ok
  end

  test "creates and injects into host app" do
    Mix.Project.in_project(:my_app, ".", fn _module ->
      Install.run(["--site", "my_site"])

      # Injects beacon repo config into config file
      # and sets Endpoint's :render_errors option
      assert File.read!(@config_path) ==
               """
               # This file is responsible for configuring your application
               # and its dependencies with the aid of the Config module.
               #
               # This configuration file is loaded before any dependency and
               # is restricted to this project.

               # General application configuration
               import Config

               config :my_app,
                 ecto_repos: [MyApp.Repo, Beacon.Repo]

               # Configures the endpoint
               config :my_app, MyAppWeb.Endpoint,
                 url: [host: "localhost"],
                 render_errors: [formats: [html: BeaconWeb.ErrorHTML, json: MyAppWeb.ErrorJSON], layout: false],
                 pubsub_server: MyApp.PubSub,
                 live_view: [signing_salt: "Ozb0CE3q"]

               # Configures the mailer
               #
               # By default it uses the "Local" adapter which stores the emails
               # locally. You can see the emails in your browser, at "/dev/mailbox".
               #
               # For production it's recommended to configure a different adapter
               # at the `config/runtime.exs`.
               config :my_app, MyApp.Mailer, adapter: Swoosh.Adapters.Local

               # Configure esbuild (the version is required)
               config :esbuild,
                 version: "0.17.11",
                 default: [
                   args:
                     ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
                   cd: Path.expand("../assets", __DIR__),
                   env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
                 ]

               # Configure tailwind (the version is required)
               config :tailwind,
                 version: "3.2.7",
                 default: [
                   args: ~w(
                     --config=tailwind.config.js
                     --input=css/app.css
                     --output=../priv/static/assets/app.css
                   ),
                   cd: Path.expand("../assets", __DIR__)
                 ]

               # Configures Elixir's Logger
               config :logger, :console,
                 format: "$time $metadata[$level] $message\n",
                 metadata: [:request_id]

               # Use Jason for JSON parsing in Phoenix
               config :phoenix, :json_library, Jason

               # Import environment specific config. This must remain at the bottom
               # of this file so it overrides the configuration defined above.
               import_config "\#{config_env()}.exs"
               """

      # Injects beacon repo config into dev config file
      assert File.read!(@dev_path) ==
               """
               import Config

               # Configure your Beacon repo
               config :beacon, Beacon.Repo,
                 username: "postgres",
                 password: "postgres",
                 hostname: "localhost",
                 database: "my_app_dev",
                 stacktrace: true,
                 show_sensitive_data_on_connection_error: true,
                 pool_size: 10

               # Configure your database
               config :my_app, MyApp.Repo,
                 username: "postgres",
                 password: "postgres",
                 hostname: "localhost",
                 database: "my_app_dev",
                 stacktrace: true,
                 show_sensitive_data_on_connection_error: true,
                 pool_size: 10

               # For development, we disable any cache and enable
               # debugging and code reloading.
               #
               # The watchers configuration can be used to run external
               # watchers to your application. For example, we can use it
               # to bundle .js and .css sources.
               config :my_app, MyAppWeb.Endpoint,
                 # Binding to loopback ipv4 address prevents access from other machines.
                 # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
                 http: [ip: {127, 0, 0, 1}, port: 4000],
                 check_origin: false,
                 code_reloader: true,
                 debug_errors: true,
                 secret_key_base: "MguLTIdkcHIhPNUVgJljuBvH1kQPpfzXuToc2l0xtSOS8vLnovVQuEOtfz3yp0uC",
                 watchers: [
                   esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
                   tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
                 ]

               # ## SSL Support
               #
               # In order to use HTTPS in development, a self-signed
               # certificate can be generated by running the following
               # Mix task:
               #
               #     mix phx.gen.cert
               #
               # Run `mix help phx.gen.cert` for more information.
               #
               # The `http:` config above can be replaced with:
               #
               #     https: [
               #       port: 4001,
               #       cipher_suite: :strong,
               #       keyfile: "priv/cert/selfsigned_key.pem",
               #       certfile: "priv/cert/selfsigned.pem"
               #     ],
               #
               # If desired, both `http:` and `https:` keys can be
               # configured to run both http and https servers on
               # different ports.

               # Watch static and templates for browser reloading.
               config :my_app, MyAppWeb.Endpoint,
                 live_reload: [
                   patterns: [
                     ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
                     ~r"priv/gettext/.*(po)$",
                     ~r"lib/my_app_web/(controllers|live|components)/.*(ex|heex)$"
                   ]
                 ]

               # Enable dev routes for dashboard and mailbox
               config :my_app, dev_routes: true

               # Do not include metadata nor timestamps in development logs
               config :logger, :console, format: "[$level] $message\n"

               # Set a higher stacktrace during development. Avoid configuring such
               # in production as building large stacktraces may be expensive.
               config :phoenix, :stacktrace_depth, 20

               # Initialize plugs at runtime for faster development compilation
               config :phoenix, :plug_init_mode, :runtime

               # Disable swoosh api client as it is only required for production adapters.
               config :swoosh, :api_client, false
               """

      # Injects beacon supervisor into application file
      assert File.read!(@application_path) ==
               """
               defmodule MyApp.Application do
                 # See https://hexdocs.pm/elixir/Application.html
                 # for more information on OTP Applications
                 @moduledoc false

                 use Application

                 @impl true
                 def start(_type, _args) do
                   children = [
                     # Start the Telemetry supervisor
                     MyAppWeb.Telemetry,
                     # Start the Ecto repository
                     MyApp.Repo,
                     # Start the PubSub system
                     {Phoenix.PubSub, name: MyApp.PubSub},
                     # Start Finch
                     {Finch, name: MyApp.Finch},
                     # Start the Endpoint (http/https)
                     MyAppWeb.Endpoint,
                     # Start a worker by calling: MyApp.Worker.start_link(arg)
                     # {MyApp.Worker, arg}
                    {Beacon, sites: [[site: :my_site, endpoint: MyAppWeb.Endpoint, router: MyAppWeb.Router]]}
               ]

                   # See https://hexdocs.pm/elixir/Supervisor.html
                   # for other strategies and supported options
                   opts = [strategy: :one_for_one, name: MyApp.Supervisor]
                   Supervisor.start_link(children, opts)
                 end

                 # Tell Phoenix to update the endpoint configuration
                 # whenever the application is updated.
                 @impl true
                 def config_change(changed, _new, removed) do
                   MyAppWeb.Endpoint.config_change(changed, removed)
                   :ok
                 end
               end
               """

      # Injects beacon scope into router file
      assert File.read!(@router_path) ==
               """
               defmodule MyAppWeb.Router do
                 use MyAppWeb, :router

                 pipeline :browser do
                   plug :accepts, ["html"]
                   plug :fetch_session
                   plug :fetch_live_flash
                   plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
                   plug :protect_from_forgery
                   plug :put_secure_browser_headers
                 end

                 pipeline :api do
                   plug :accepts, ["json"]
                 end

                 scope "/", MyAppWeb do
                   pipe_through :browser

                   get "/", PageController, :home
                 end

                 # Other scopes may use custom stacks.
                 # scope "/api", MyAppWeb do
                 #   pipe_through :api
                 # end

                 # Enable LiveDashboard and Swoosh mailbox preview in development
                 if Application.compile_env(:test_app, :dev_routes) do
                   # If you want to use the LiveDashboard in production, you should put
                   # it behind authentication and allow only admins to access it.
                   # If your application does not have an admins-only section yet,
                   # you can use Plug.BasicAuth to set up some basic authentication
                   # as long as you are also using SSL (which you should anyway).
                   import Phoenix.LiveDashboard.Router

                   scope "/dev" do
                     pipe_through :browser

                     live_dashboard "/dashboard", metrics: MyAppWeb.Telemetry
                     forward "/mailbox", Plug.Swoosh.MailboxPreview
                   end
                 end

                 use Beacon.Router

                 scope "/" do
                   pipe_through :browser
                   beacon_site "/my_site", site: :my_site
                 end
               end
               """
    end)
  end

  test "idempotence" do
    Mix.Project.in_project(:my_app, ".", fn _module ->
      Install.run(["--site", "my_site"])

      # Content after first run
      config = File.read!(@config_path)
      dev = File.read!(@dev_path)
      app = File.read!(@application_path)
      router = File.read!(@router_path)
      mixfile = File.read!(@mixfile_path)

      Install.run(["--site", "my_site"])

      # File contents have not changed after second run
      assert File.read!(@config_path) == config
      assert File.read!(@dev_path) == dev
      assert File.read!(@application_path) == app
      assert File.read!(@router_path) == router
      assert File.read!(@mixfile_path) == mixfile
    end)
  end

  test "raises with bad options" do
    Mix.Project.in_project(:my_app, ".", fn _module ->
      # Missing site name
      assert_raise Mix.Error, fn ->
        Install.run([])
      end

      # Invalid site name
      assert_raise Mix.Error, fn ->
        Install.run(["--site", "my@site!"])
      end

      # Invalid site name
      assert_raise Mix.Error, fn ->
        Install.run(["--site", "beacon_"])
      end

      # Invalid path value
      assert_raise Mix.Error, fn ->
        Install.run(["--site", "blog", "--path", "forgot_slash_at_beginning"])
      end

      # Invalid option
      assert_raise OptionParser.ParseError, ~r/1 error found!\n--invalid-argument : Unknown option/, fn ->
        Install.run(["--invalid-argument", "invalid"])
      end
    end)
  end

  test "SUCCESS: New flag --path value updates beacon_path" do
    Mix.Project.in_project(:my_app, ".", fn _module ->
      Install.run(["--site", "my_site", "--path", "/some_other_path"])

      # Injects beacon scope into router file
      assert File.read!(@router_path) ==
               """
               defmodule MyAppWeb.Router do
                 use MyAppWeb, :router

                 pipeline :browser do
                   plug :accepts, ["html"]
                   plug :fetch_session
                   plug :fetch_live_flash
                   plug :put_root_layout, html: {MyAppWeb.Layouts, :root}
                   plug :protect_from_forgery
                   plug :put_secure_browser_headers
                 end

                 pipeline :api do
                   plug :accepts, ["json"]
                 end

                 scope "/", MyAppWeb do
                   pipe_through :browser

                   get "/", PageController, :home
                 end

                 # Other scopes may use custom stacks.
                 # scope "/api", MyAppWeb do
                 #   pipe_through :api
                 # end

                 # Enable LiveDashboard and Swoosh mailbox preview in development
                 if Application.compile_env(:test_app, :dev_routes) do
                   # If you want to use the LiveDashboard in production, you should put
                   # it behind authentication and allow only admins to access it.
                   # If your application does not have an admins-only section yet,
                   # you can use Plug.BasicAuth to set up some basic authentication
                   # as long as you are also using SSL (which you should anyway).
                   import Phoenix.LiveDashboard.Router

                   scope "/dev" do
                     pipe_through :browser

                     live_dashboard "/dashboard", metrics: MyAppWeb.Telemetry
                     forward "/mailbox", Plug.Swoosh.MailboxPreview
                   end
                 end

                 use Beacon.Router

                 scope "/" do
                   pipe_through :browser
                   beacon_site "/some_other_path", site: :my_site
                 end
               end
               """
    end)
  end
end
