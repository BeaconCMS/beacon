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
      ~r"lib/beacon/.*(ex)$",
      ~r"lib/beacon_web/(live|views)/.*(ex)$"
    ]
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

defmodule SamplePhoenix.LayoutView do
  import Phoenix.Component, only: [sigil_H: 2]
  alias SampleAppWeb.Router.Helpers, as: Routes

  def render("root.html", assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <script src="https://cdn.tailwindcss.com">
        </script>
        <script src="https://cdn.jsdelivr.net/npm/phoenix@1.7.0-rc.0/priv/static/phoenix.min.js">
        </script>
        <script src="https://cdn.jsdelivr.net/npm/phoenix_live_view@0.18.3/priv/static/phoenix_live_view.min.js">
        </script>
        <script>
          let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket)
          liveSocket.connect()
        </script>
      </head>
      <body>
        <%= @inner_content %>
      </body>
    </html>
    """
  end

  def render("live.html", assigns) do
    ~H"""
    <%= @inner_content %>
    """
  end
end

defmodule Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router
  require BeaconWeb.PageManagement

  pipeline :browser do
    plug :accepts, ["html"]
    plug :put_root_layout, {SamplePhoenix.LayoutView, :root}
  end

  pipeline :beacon do
    plug BeaconWeb.Plug
  end

  scope "/page_management", BeaconWeb.PageManagement do
    pipe_through :browser
    BeaconWeb.PageManagement.routes()
  end

  scope "/", BeaconWeb do
    pipe_through :browser
    pipe_through :beacon

    live_session :beacon, session: %{"beacon_site" => "my_site"} do
      live "/beacon/*path", PageLive, :path
    end
  end
end

defmodule SamplePhoenix.Endpoint do
  use Phoenix.Endpoint, otp_app: :sample
  socket "/live", Phoenix.LiveView.Socket
  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
  plug Phoenix.LiveReloader
  plug Phoenix.CodeReloader
  plug Router
end

defmodule BeaconDataSource do
  @behaviour Beacon.DataSource.Behaviour

  def live_data(_, _, _), do: %{}
end

Ecto.Migrator.with_repo(Beacon.Repo, &Ecto.Migrator.run(&1, :down, all: true))
Ecto.Migrator.with_repo(Beacon.Repo, &Ecto.Migrator.run(&1, :up, all: true))

Beacon.Stylesheets.create_stylesheet!(%{
  site: "my_site",
  name: "sample_stylesheet",
  content: "body {cursor: zoom-in;}"
})

Beacon.Components.create_component!(%{
  site: "my_site",
  name: "sample_component",
  body: """
  <%= @val %>
  """
})

%{id: layout_id} =
  Beacon.Layouts.create_layout!(%{
    site: "my_site",
    title: "Dev",
    meta_tags: %{},
    stylesheet_urls: [],
    body: """
    <%= @inner_content %>
    """
  })

Beacon.Pages.create_page!(%{
  path: "home",
  site: "my_site",
  layout_id: layout_id,
  template: """
  <main>
    <h1>Dev</h1>
    <%= my_component("sample_component", val: 1) %>
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
