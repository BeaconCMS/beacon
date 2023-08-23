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
  http: [ip: {127, 0, 0, 1}, port: 4001],
  server: true,
  live_view: [signing_salt: "aaaaaaaa"],
  secret_key_base: String.duplicate("a", 64),
  debug_errors: true,
  check_origin: false,
  pubsub_server: SamplePhoenix.PubSub,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/beacon/.*(ex)$",
      ~r"lib/beacon_web/(controllers|live|components)/.*(ex|heex)$"
    ]
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
    plug :accepts, ["html", "json"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug BeaconWeb.API.Plug
  end

  scope "/" do
    pipe_through :browser
    beacon_site "/dev", site: :dev
    beacon_site "/other", site: :other
  end

  scope "/" do
    pipe_through :api
    beacon_api "/api"
  end
end

defmodule SamplePhoenix.Endpoint do
  use Phoenix.Endpoint, otp_app: :beacon

  @session_options [store: :cookie, key: "_beacon_dev_key", signing_salt: "pMQYsz0UKEnwxJnQrVwovkBAKvU3MiuL"]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]
  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket

  plug Phoenix.LiveReloader
  plug Phoenix.CodeReloader

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug SamplePhoenixWeb.Router
end

defmodule BeaconDataSource do
  @behaviour Beacon.DataSource.Behaviour

  def live_data(:dev, ["home"], _params) do
    [img1] = Beacon.MediaLibrary.search(:dev, "dockyard_1")

    %{year: Date.utc_today().year, img1: img1}
  end

  def live_data(_, _, _), do: %{}

  def page_title(:dev, %{page_title: page_title}), do: String.upcase(page_title)

  def meta_tags(:dev, %{beacon_live_data: %{year: year}, meta_tags: meta_tags}) do
    [%{"name" => "year", "content" => year} | meta_tags]
  end

  def meta_tags(:dev, %{meta_tags: meta_tags}), do: meta_tags
end

defmodule BeaconTagsField do
  use Phoenix.Component
  import BeaconWeb.CoreComponents
  import Ecto.Changeset

  @behaviour Beacon.Content.PageField

  @impl true
  def name, do: :tags

  @impl true
  def type, do: :string

  @impl true
  def default, do: "beacon,dev"

  @impl true
  def render(assigns) do
    ~H"""
    <.input type="text" label="Tags" field={@field} />
    """
  end

  @impl true
  def changeset(data, attrs, _metadata) do
    data
    |> cast(attrs, [:tags])
    |> validate_required([:tags])
    |> validate_format(:tags, ~r/,/, message: "invalid format, expected ,")
  end
end

seeds = fn ->
  Beacon.Content.create_stylesheet!(%{
    site: "dev",
    name: "sample_stylesheet",
    content: "body {cursor: zoom-in;}"
  })

  Beacon.Content.create_component!(%{
    site: "dev",
    name: "sample_component",
    body: """
    <%= @val %>
    """,
    category: "other"
  })

  layout =
    Beacon.Content.create_layout!(%{
      site: "dev",
      title: "dev",
      meta_tags: [
        %{"name" => "layout-meta-tag-one", "content" => "value"},
        %{"name" => "layout-meta-tag-two", "content" => "value"}
      ],
      resource_links: [
        %{"rel" => "stylesheet", "href" => "print.css", "media" => "print"},
        %{"rel" => "stylesheet", "href" => "alternative.css"}
      ],
      template: """
      <%= @inner_content %>
      """
    })

  Beacon.Content.publish_layout(layout)

  Beacon.Content.create_snippet_helper!(%{
    site: "dev",
    name: "author_name",
    body: ~S"""
    author_id =  get_in(assigns, ["page", "extra", "author_id"])
    "author_#{author_id}"
    """
  })

  metadata =
    Beacon.MediaLibrary.UploadMetadata.new(
      :dev,
      Path.join(:code.priv_dir(:beacon), "assets/dockyard-wide.jpeg"),
      name: "dockyard_1.png",
      size: 196_000,
      extra: %{"alt" => "logo"}
    )

  img1 = Beacon.MediaLibrary.upload(metadata)

  metadata =
    Beacon.MediaLibrary.UploadMetadata.new(
      :dev,
      Path.join(:code.priv_dir(:beacon), "assets/dockyard-wide.jpeg"),
      name: "dockyard_2.png",
      size: 196_000,
      extra: %{"alt" => "alternate logo"}
    )

  img2 = Beacon.MediaLibrary.upload(metadata)

  page_home =
    Beacon.Content.create_page!(%{
      path: "home",
      site: "dev",
      title: "dev home",
      description: "page used for development",
      layout_id: layout.id,
      meta_tags: [
        %{"property" => "og:title", "content" => "title: {{ page.title | upcase }}"}
      ],
      raw_schema: [
        %{
          "@context": "https://schema.org",
          "@type": "BlogPosting",
          headline: "{{ page.description }}",
          author: %{
            "@type": "Person",
            name: "{% helper 'author_name' %}"
          }
        }
      ],
      extra: %{
        "author_id" => 1
      },
      template: """
      <main>
        <h1 class="text-violet-500">Dev</h1>
        <p class="text-sm">Page</p>

        <div>
          <p>Pages:</p>
          <ul>
            <li><.link patch="/dev/authors/1-author">Author (patch)</.link></li>
            <li><.link navigate="/dev/posts/2023/my-post">Post (navigate)</.link></li>
            <li><.link navigate="/dev/markdown">Markdown Page</.link></li>
          </ul>
        </div>

        <div>
          Sample component: <%= my_component("sample_component", val: 1) %>
        </div>

        <div>
          <BeaconWeb.Components.image_set asset={@beacon_live_data[:img1]} sources={["480w"]} width="200px" />
        </div>

        <div>
          <p>From data source:</p>
          <%= @beacon_live_data[:year] %>
        </div>

        <div>
          <p>From dynamic_helper:</p>
          <%= dynamic_helper("upcase", %{name: "beacon"}) %>
        </div>

        <div>
          <p>RANDOM:<%= Enum.random(1..100) %></p>
        </div>
      </main>
      """,
      helpers: [
        %{
          name: "upcase",
          args: "%{name: name}",
          code: """
            String.upcase(name)
          """
        }
      ]
    })

  Beacon.Content.publish_page(page_home)

  page_author =
    Beacon.Content.create_page!(%{
      path: "authors/:author_id",
      site: "dev",
      title: "dev author",
      layout_id: layout.id,
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

  Beacon.Content.publish_page(page_author)

  page_post =
    Beacon.Content.create_page!(%{
      path: "posts/*slug",
      site: "dev",
      title: "dev post",
      layout_id: layout.id,
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

  Beacon.Content.publish_page(page_post)

  page_markdown =
    Beacon.Content.create_page!(%{
      path: "markdown",
      site: "dev",
      title: "dev markdown",
      layout_id: layout.id,
      format: "markdown",
      template: """
      # My Markdown Page

      ## Intro

      Back to [Home](/dev/home)
      """
    })

  Beacon.Content.publish_page(page_markdown)

  other_layout =
    Beacon.Content.create_layout!(%{
      site: "other",
      title: "other",
      template: """
      <%= @inner_content %>
      """
    })

  Beacon.Content.publish_layout(other_layout)

  Beacon.Content.create_page!(%{
    path: "home",
    site: "other",
    title: "other home",
    layout_id: other_layout.id,
    template: """
    <main>
      <h1 class="text-violet-500">Other</h1>
    </main>
    """
  })
end

dev_site = [
  site: :dev,
  endpoint: SamplePhoenix.Endpoint,
  data_source: BeaconDataSource,
  extra_page_fields: [BeaconTagsField],
  lifecycle: [upload_asset: [thumbnail: &Beacon.Lifecycle.Asset.thumbnail/2, _480w: &Beacon.Lifecycle.Asset.variant_480w/2]]
]

s3_bucket = System.get_env("S3_BUCKET")
Application.put_env(:ex_aws, :s3, bucket: s3_bucket)

dev_site =
  case s3_bucket do
    nil ->
      dev_site

    _ ->
      assets = [
        {"image/*", [backends: [Beacon.MediaLibrary.Backend.S3.Unsigned, Beacon.MediaLibrary.Backend.Repo], validations: []]}
      ]

      Keyword.put(dev_site, :assets, assets)
  end

Task.start(fn ->
  children = [
    {Phoenix.PubSub, [name: SamplePhoenix.PubSub]},
    {Beacon,
     sites: [
       dev_site,
       [site: :other, endpoint: SamplePhoenix.Endpoint]
     ]},
    SamplePhoenix.Endpoint
  ]

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

  # TODO: revert this change and remove ecto.reset from mix dev alias
  # Ecto.Migrator.with_repo(Beacon.Repo, &Ecto.Migrator.run(&1, :down, all: true))
  # Ecto.Migrator.with_repo(Beacon.Repo, &Ecto.Migrator.run(&1, :up, all: true))

  seeds.()

  :ok = Beacon.reload_site(:dev)
  :ok = Beacon.reload_site(:other)

  Process.sleep(:infinity)
end)
