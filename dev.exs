# mix run --no-halt dev.exs
#
# Refs:
# https://github.com/mcrumm/phoenix_profiler/blob/b882314add2d8783aac76b87c8ded3c123fc71a4/dev.exs
# https://github.com/chrismccord/single_file_phoenix_fly/blob/bd3b372a5ca94cdd77d22b4fa1818cc4b612bcf5/run.exs
# https://github.com/wojtekmach/mix_install_examples/blob/2c30c129f36206d3dfa234421ec5869e5e2e82be/phoenix_live_view.exs
# https://github.com/wojtekmach/mix_install_examples/blob/2c30c129f36206d3dfa234421ec5869e5e2e82be/ecto_sql.exs

require Logger
Logger.configure(level: :debug)

Application.put_env(:phoenix, :json_library, Jason)

Application.put_env(:sample, SamplePhoenix.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  server: true,
  live_view: [signing_salt: "aaaaaaaa"],
  secret_key_base: String.duplicate("a", 64),
  debug_errors: true,
  check_origin: false,
  pubsub_server: SamplePhoenix.PubSub,
  live_reload: [
    patterns: [
      ~r"dev/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"dist/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/beacon/.*(ex)$",
      ~r"lib/beacon_web/(live|views)/.*(ex)$"
    ]
  ],
  watchers: [
    tailwind: {Tailwind, :install_and_run, [:admin_dev, ~w(--watch)]}
  ]
)

Application.put_env(:beacon, :data_source, BeaconDataSource)

Application.put_env(:beacon, Beacon.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "beacon_sample_app_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true
)

defmodule SamplePhoenix.ErrorView do
  use Phoenix.View, root: ""
  def render(_, _), do: "error"
end

defmodule SamplePhoenixWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router
  import Beacon.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/admin" do
    pipe_through :browser
    beacon_admin "/"
  end

  scope "/dev" do
    pipe_through :browser
    beacon_site "/", name: "dev"
  end
end

defmodule SamplePhoenix.Endpoint do
  use Phoenix.Endpoint, otp_app: :sample

  @session_options [store: :cookie, key: "_beacon_dev_key", signing_salt: "pMQYsz0UKEnwxJnQrVwovkBAKvU3MiuL"]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]
  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket

  plug Plug.Static,
    at: "/dev",
    from: "dev/static",
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  plug Phoenix.LiveReloader
  plug Phoenix.CodeReloader
  plug Plug.RequestId
  plug Plug.Session, @session_options
  plug SamplePhoenixWeb.Router
end

defmodule BeaconDataSource do
  @behaviour Beacon.DataSource.Behaviour

  def live_data(_, _, _), do: %{}
end

Ecto.Migrator.with_repo(Beacon.Repo, &Ecto.Migrator.run(&1, :down, all: true))
Ecto.Migrator.with_repo(Beacon.Repo, &Ecto.Migrator.run(&1, :up, all: true))

Beacon.Stylesheets.create_stylesheet!(%{
  site: "dev",
  name: "sample_stylesheet",
  content: "body {cursor: zoom-in;}"
})

Beacon.Components.create_component!(%{
  site: "dev",
  name: "sample_component",
  body: """
  <%= @val %>
  """
})

%{id: layout_id} =
  Beacon.Layouts.create_layout!(%{
    site: "dev",
    title: "Dev",
    meta_tags: %{"env" => "dev"},
    stylesheet_urls: [],
    body: """
    <%= @inner_content %>
    """
  })

Beacon.Pages.create_page!(%{
  path: "home",
  site: "dev",
  layout_id: layout_id,
  template: """
  <main>
    <h1 class="text-violet-900">Dev</h1>
    <p class="text-sm">Page</p>
    <%= my_component("sample_component", val: 1) %>

    <pre><code>
      <%= inspect(Phoenix.Router.route_info(SamplePhoenixWeb.Router, "GET", "/dev/home", "host"), pretty: true) %>
    </code></pre>
  </main>
  """
})

Application.ensure_all_started(:plug_cowboy)
Application.ensure_all_started(:cowboy_websocket)
Application.ensure_all_started(:beacon)

children = [
  {Phoenix.PubSub, [name: SamplePhoenix.PubSub]},
  SamplePhoenix.Endpoint
]

{:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

Process.sleep(:infinity)
