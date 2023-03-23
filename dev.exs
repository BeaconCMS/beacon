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

Application.put_env(:beacon, SamplePhoenix.Endpoint,
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
  use Beacon.Router
  import Phoenix.LiveView.Router

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
    beacon_site "/dev", site: :dev
    beacon_site "/other", site: :other
  end
end

defmodule SamplePhoenix.Endpoint do
  use Phoenix.Endpoint, otp_app: :beacon

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

  def live_data(:dev, ["home"], _params), do: %{year: Date.utc_today().year}
  def live_data(_, _, _), do: %{}

  def page_title(:dev, %{page_title: page_title}), do: String.upcase(page_title)

  def meta_tags(:dev, %{beacon_live_data: %{year: year}, meta_tags: meta_tags}) do
    [%{"name" => "year", "content" => year} | meta_tags]
  end

  def meta_tags(:dev, %{meta_tags: meta_tags}), do: meta_tags
end

seeds = fn ->
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
      title: "dev",
      meta_tags: [
        %{"name" => "layout-meta-tag-one", "content" => "value"},
        %{"name" => "layout-meta-tag-two", "content" => "value"}
      ],
      stylesheet_urls: [],
      body: """
      <%= @inner_content %>
      """
    })

  page_home =
    Beacon.Pages.create_page!(%{
      path: "home",
      site: "dev",
      title: "dev home",
      description: "page used for development",
      layout_id: layout_id,
      meta_tags: [
        %{"property" => "og:title", "content" => "home"}
      ],
      template: """
      <main>
        <h1 class="text-violet-500">Dev</h1>
        <p class="text-sm">Page</p>

        <div>
          <p>Pages:</p>
          <ul>
            <li><.link patch="/dev/authors/1-author">Author (patch)</.link></li>
            <li><.link navigate="/dev/posts/2023/my-post">Post (navigate)</.link></li>
          </ul>
        </div>

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
      </main>
      """
    })

  _page_author =
    Beacon.Pages.create_page!(%{
      path: "authors/:author_id",
      site: "dev",
      title: "dev author",
      layout_id: layout_id,
      template: """
      <main>
        <h1 class="text-violet-500">Authors</h1>

        <div>
          <p>Pages:</p>
          <ul>
            <li><.link navigate="/dev/home">Home (navigate)</.link></li>
            <li><.link navigate="/dev/posts/2023/my-post">Post (navigate)</.link></li>
          </ul>
        </div>

        <div>
          <p>path params:</p>
          <p><%= inspect @beacon_path_params %></p>
        </div>
      </main>
      """
    })

  _page_post =
    Beacon.Pages.create_page!(%{
      path: "posts/*slug",
      site: "dev",
      title: "dev post",
      layout_id: layout_id,
      template: """
      <main>
        <h1 class="text-violet-500">Post</h1>

        <div>
          <p>Pages:</p>
          <ul>
            <li><.link navigate="/dev/home">Home (navigate)</.link></li>
            <li><.link patch="/dev/authors/1-author">Author (patch)</.link></li>
          </ul>
        </div>

        <div>
          <p>path params:</p>
          <p><%= inspect @beacon_path_params %></p>
        </div>
      </main>
      """
    })

  Beacon.Pages.create_page_helper!(%{
    page_id: page_home.id,
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

  %{id: other_layout_id} =
    Beacon.Layouts.create_layout!(%{
      site: "other",
      title: "other",
      stylesheet_urls: [],
      body: """
      <%= @inner_content %>
      """
    })

  Beacon.Pages.create_page!(%{
    path: "home",
    site: "other",
    title: "other home",
    layout_id: other_layout_id,
    template: """
    <main>
      <h1 class="text-violet-500">Other</h1>
    </main>
    """
  })
end

Task.start(fn ->
  children = [
    {Phoenix.PubSub, [name: SamplePhoenix.PubSub]},
    {Beacon, sites: [[site: :dev, data_source: BeaconDataSource], [site: :other]]},
    SamplePhoenix.Endpoint
  ]

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

  Ecto.Migrator.with_repo(Beacon.Repo, &Ecto.Migrator.run(&1, :down, all: true))
  Ecto.Migrator.with_repo(Beacon.Repo, &Ecto.Migrator.run(&1, :up, all: true))

  seeds.()

  Beacon.reload_all_sites()

  Process.sleep(:infinity)
end)
