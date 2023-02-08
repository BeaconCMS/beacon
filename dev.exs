# Development Server for Beacon
#
# Usage:
#
#     $ iex -S mix dev
#
# Refs:
#
# https://github.com/phoenixframework/phoenix_live_dashboard/blob/e87bbe03203f67947643f0574bb272b681951fa8/dev.exs
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
      ~r"assets/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"dev/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/beacon/.*(ex)$",
      ~r"lib/beacon_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ],
  watchers: [
    tailwind: {Tailwind, :install_and_run, [:admin_dev, ~w(--watch)]}
  ]
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

  scope "/" do
    pipe_through :browser
    beacon_admin "/admin"
    beacon_site "/dev", name: "dev", data_source: BeaconDataSource
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

  def live_data("dev", ["home"], _params), do: %{year: Date.utc_today().year}
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
    meta_tags: %{"layout" => "dev"},
    stylesheet_urls: [],
    body: """
    <%= @inner_content %>
    """
  })

page =
  Beacon.Pages.create_page!(%{
    path: "home",
    site: "dev",
    layout_id: layout_id,
    meta_tags: %{"page" => "home"},
    template: """
    <main>
      <h1 class="text-violet-900">Dev</h1>
      <p class="text-sm">Page</p>
      <%= my_component("sample_component", val: 1) %>
      <div>
        <BeaconWeb.Components.image beacon_attrs={@beacon_attrs} name="dockyard_1.png" width="200px" />
      </div>

      <div>
        <p>From data source:</p>
        <%= @beacon_live_data[:year] %>
      </div>

      <div>
        <p>From dynamic_helper:</p>
        <%= dynamic_helper("upcase", %{name: "beacon"}) %>
      </div>

      <pre><code>
        <%= inspect(Phoenix.Router.routes(SamplePhoenixWeb.Router), pretty: true) %>
      </code></pre>
    </main>
    """
  })

Beacon.Pages.create_page_helper!(%{
  page_id: page.id,
  helper_name: "upcase",
  helper_args: "%{name: name}",
  code: """
    String.upcase(name)
  """
})

Beacon.Admin.MediaLibrary.upload(
  "dev",
  Path.join(:code.priv_dir(:beacon), "assets/dockyard.png"),
  "dockyard_1.png",
  "image/png"
)

Beacon.Admin.MediaLibrary.upload(
  "dev",
  Path.join(:code.priv_dir(:beacon), "assets/dockyard.png"),
  "dockyard_2.jpg",
  "image/jpg"
)

Task.start(fn ->
  children = [
    {Phoenix.PubSub, [name: SamplePhoenix.PubSub]},
    SamplePhoenix.Endpoint
  ]

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

  Process.sleep(:infinity)
end)
