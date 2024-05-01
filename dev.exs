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

display_error_pages? = false

Application.put_env(:beacon, SamplePhoenix.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4001],
  server: true,
  live_view: [signing_salt: "aaaaaaaa"],
  secret_key_base: String.duplicate("a", 64),
  debug_errors: !display_error_pages?,
  render_errors: [formats: [html: BeaconWeb.ErrorHTML]],
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
    beacon_site "/dy", site: :dy
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
    |> validate_format(:tags, ~r/,/, message: "invalid format, expected ,")
  end
end

dev_seeds = fn ->
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

  Beacon.Content.create_component!(%{
    site: "dev",
    name: "sample_component",
    body: """
    <li>
      <%= @val %>
    </li>
    """
  })

  Beacon.Content.create_snippet_helper!(%{
    site: "dev",
    name: "author_name",
    body: ~S"""
    author_id = get_in(assigns, ["page", "extra", "author_id"])
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

  _img1 = Beacon.MediaLibrary.upload(metadata)

  metadata =
    Beacon.MediaLibrary.UploadMetadata.new(
      :dev,
      Path.join(:code.priv_dir(:beacon), "assets/dockyard-wide.jpeg"),
      name: "dockyard_2.png",
      size: 196_000,
      extra: %{"alt" => "alternate logo"}
    )

  _img2 = Beacon.MediaLibrary.upload(metadata)

  home_live_data = Beacon.Content.create_live_data!(%{site: "dev", path: "/sample"})

  Beacon.Content.create_assign_for_live_data(
    home_live_data,
    %{
      format: :elixir,
      key: "year",
      value: """
      Date.utc_today().year
      """
    }
  )

  Beacon.Content.create_assign_for_live_data(
    home_live_data,
    %{
      format: :elixir,
      key: "img1",
      value: """
      [img1] = Beacon.MediaLibrary.search(:dev, "dockyard_1")
      img1
      """
    }
  )

  page_home =
    Beacon.Content.create_page!(%{
      path: "/sample",
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
        <%!-- Home Page --%>

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
          <!-- %= dynamic_helper("upcase", %{name: "beacon"}) %> -->
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
      path: "/authors/:author_id",
      site: "dev",
      title: "dev author",
      layout_id: layout.id,
      template: """
      <main>
        <h1 class="text-violet-500">Authors</h1>

        <div>
          <p>Pages:</p>
          <ul>
            <li><.link navigate="/dev">Home (navigate)</.link></li>
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
      path: "/posts/*slug",
      site: "dev",
      title: "dev post",
      layout_id: layout.id,
      template: """
      <main>
        <h1 class="text-violet-500">Post</h1>

        <div>
          <p>Pages:</p>
          <ul>
            <li><.link navigate="/dev">Home (navigate)</.link></li>
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
      path: "/markdown",
      site: "dev",
      title: "dev markdown",
      layout_id: layout.id,
      format: "markdown",
      template: """
      # My Markdown Page

      ## Intro

      Back to [Home](/dev)
      """
    })

  Beacon.Content.publish_page(page_markdown)
end

dy_seeds = fn ->
  Beacon.Content.create_component!(%{
    site: "dy",
    name: "header",
    body: """
    <header class="sticky top-0 left-0 z-50 w-full px-4 bg-white font-body">
      <nav class="flex items-center justify-between mx-auto lg:h-25 h-21 gap-x-3 max-w-7xl" aria-label="Main" id="nav-main">
      <.link navigate="/" class="rounded focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-200 focus-visible:ring-offset-8">
        <svg class="icon-svg dy-logo-full" width="136" height="35" viewBox="0 0 319.59 82.14" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="DockYard Home">
          <title>DockYard Home</title>
          <path class="cls-1" d="M42.72 31.54A1.78 1.78 0 1 0 45 32.69a1.77 1.77 0 0 0-2.24-1.15"></path>
          <path class="cls-1" d="M41.07 0a41.07 41.07 0 1 0 41.07 41.07A41.07 41.07 0 0 0 41.07 0m23.81 16.24a1.72 1.72 0 0 1-.44.73c-.75.87-8.91 10-11.95 13.06 1.32 3.41 1.32 9.23.85 14.88-.66 8-1.71 11.16-6 13.6s-16.24 2.77-22.18 1.31-6.68-7.41-7.25-7.66c-2.32-1-2-4.65-2-4.65 1.63-.08 3.26 2 3.26 2a7.92 7.92 0 0 1 2.61-2c.89 3.18-1 4.24-.82 4.65.47 1.17 3 4 7 2s4.15-7.57 4.4-14.42 2-12.3 7.9-13.6a14.25 14.25 0 0 1 9.25.83c4-3 13.28-9.57 14.1-10.14a4.59 4.59 0 0 1 .86-.51h.43z"></path>
          <path class="cls-1" d="M38 46.35c-1.3 1.84-1.69 3.55-2.53 5.54-.67 1.61-1.9 2.36-2.79 3.69-.68 1.13 1.69 1.53 2.32 1.55a6 6 0 0 0 4.73-2.24c1.41-1.9 1.56-3.78 2.54-5.81.53-1.08 2.13-3.16 2.22-4.16.18-1.84-4.58-1.29-6.5 1.43M102.3 27.41h9.64c8.16 0 13.35 5.66 13.35 13.66s-5.19 13.66-13.35 13.66h-9.64zm3.46 3.29v20.74h6.14c6.11 0 9.81-4.38 9.81-10.37S118 30.7 111.9 30.7zM145 27a13.78 13.78 0 0 1 14 14.07 14.07 14.07 0 1 1-28.13 0A13.78 13.78 0 0 1 145 27m0 24.71a10.39 10.39 0 0 0 10.49-10.65 10.47 10.47 0 1 0-20.94 0A10.37 10.37 0 0 0 145 51.72M185.81 53.25a14.3 14.3 0 0 1-7.2 1.89 13.78 13.78 0 0 1-14.06-14.07A13.78 13.78 0 0 1 178.61 27a14.3 14.3 0 0 1 7.2 1.88V33a11.07 11.07 0 0 0-7.2-2.53 10.4 10.4 0 0 0-10.45 10.65 10.35 10.35 0 0 0 10.45 10.65 11.12 11.12 0 0 0 7.2-2.49zM194.14 27.41h3.45v13.38l10.21-13.38h4.14l-8.44 11.17 8.84 16.15h-4.1l-7.15-13.26-3.5 4.38v8.88h-3.45V27.41zM226.27 42.64l-9.04-15.23h3.93L228 39.18l6.87-11.77h3.98l-9.13 15.27v12.05h-3.45V42.64zM257.45 47.1h-11l-2.78 7.64h-3.89L250 27.41h3.9l10.3 27.33h-3.9zm-9.89-3.34h8.76L251.94 32zM270.75 27.41h8.07c5.11 0 8.6 2.85 8.6 7.67a6.86 6.86 0 0 1-5.62 7c3.25 1.52 6.07 6.18 7.07 12.65h-3.58c-1.24-6.79-4.66-11.41-8.24-11.41h-2.85v11.41h-3.45zm8.07 3.29h-4.62V40h4.62c2.86 0 5-1.65 5-4.63s-2.17-4.7-5-4.7M296.61 27.41h9.64c8.16 0 13.34 5.66 13.34 13.66s-5.18 13.66-13.34 13.66h-9.64zm3.45 3.29v20.74h6.15c6.11 0 9.81-4.38 9.81-10.37s-3.7-10.37-9.81-10.37z"></path>
        </svg>
      </.link>

      <button
        class="flex items-center justify-center w-10 h-10 bg-gray-100 rounded-lg hover:outline-blue-400 hover:outline focus-visible:outline focus-visible:outline-4 focus-visible:outline-blue-200 lg:hidden"
        aria-controls="primary-navigation"
        id="nav-button-show"
        aria-hidden="false"
        aria-expanded="false"
      >
        <span class="sr-only">Show Primary Navigation</span>
        <svg width="17" height="14" viewBox="0 0 17 14" fill="none" xmlns="http://www.w3.org/2000/svg" role="presentation">
          <path d="M16.6667 12V13.6666H1.66671V12H16.6667ZM4.66337 0.253296L5.84171 1.43163L3.19004 4.0833L5.84171 6.73496L4.66337 7.9133L0.833374 4.0833L4.66337 0.253296ZM16.6667 6.16663V7.8333H9.16671V6.16663H16.6667ZM16.6667 0.333296V1.99996H9.16671V0.333296H16.6667Z" fill="#304254" />
        </svg>
      </button>
      <button
        class="flex items-center justify-center hidden w-10 h-10 bg-gray-100 rounded-lg hover:outline-blue-400 hover:outline focus-visible:outline focus-visible:outline-4 focus-visible:outline-blue-200 lg:hidden"
        aria-controls="primary-navigation"
        id="nav-button-hide"
        aria-hidden="true"
        aria-expanded="true"
      >
        <span class="sr-only">Hide Primary Navigation</span>
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none" xmlns="http://www.w3.org/2000/svg" role="presentation">
          <path d="M6.16661 4.82166L10.2916 0.696655L11.4699 1.87499L7.34495 5.99999L11.4699 10.125L10.2916 11.3033L6.16661 7.17832L2.04161 11.3033L0.863281 10.125L4.98828 5.99999L0.863281 1.87499L2.04161 0.696655L6.16661 4.82166Z" fill="#1C2A3A" />
        </svg>
      </button>
      <div
        class="fixed inset-0 z-10 flex flex-col items-center invisible w-full h-0 px-4 pt-8 pb-0 overflow-y-auto transition-opacity duration-300 bg-white opacity-0 lg:visible lg:static lg:top-auto lg:ml-auto lg:flex-row lg:items-center lg:justify-end lg:gap-y-0 lg:gap-x-10 lg:px-1 lg:py-1 lg:opacity-100 xl:gap-x-14 lg:h-auto top-20 gap-y-10"
        id="primary-navigation"
      >
        <% link_collection = [
          {"Services", "/services"},
          {"Work", "/work"},
          {"Why DockYard", "/why-dockyard"},
          {"Blog", "/blog"},
          {"Culture", "/culture"}
        ] %>
        <%= for {link_text, link_path} <- link_collection do %>
          <.link
            navigate={link_path}
            class="text-2xl font-medium text-gray-600 rounded hover:text-blue-600 hover:underline focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-200 focus-visible:ring-offset-8 active:text-blue-600 lg:text-lg"
          >
            <%= link_text %>
          </.link>
        <% end %>
        <.link
          class="hover:bg-blue-700 focus:outline-none focus-visible:ring-4 focus-visible:ring-blue-200 active:bg-blue-800 lg:mt-0 lg:w-auto lg:px-10 block py-4 mt-10 w-full font-medium tracking-widest text-center text-gray-50 uppercase bg-blue-600 rounded-lg"
          navigate="/contact/hire-us"
        >
          Book Meeting
        </.link>
        <p class="mt-auto text-xs text-gray-500 lg:hidden">
          Copyright <%= DateTime.utc_now().year %>. DockYard Inc. All Rights Reserved
        </p>
      </div>
      </nav>
    </header>
    """
  })

  Beacon.Content.create_component!(%{
    site: "dy",
    name: "footer",
    body: """
    <footer class="py-15 pb-15 font-body md:py-20 lg:py-24 xl:py-30 text-gray-50 px-4 bg-gray-700">
      <%!-- Footer CTA --%>
      <div class="max-w-7xl mx-auto">
        <div class="md:flex-row md:items-end md:justify-between md:pb-10 lg:pb-14 xl:pb-20 flex flex-col pb-8 border-b border-gray-600">
          <div class="font-heading xl:max-w-xs grid">
            <h2 class="lg:text-3xl xl:text-4xl xl:leading-normal text-2xl font-bold">
              Let's build for the future
            </h2>
            <h3 class="-order-1 text-eyebrow tracking-widestXl lg:mb-0 lg:text-base mb-2 font-medium uppercase">
              Grow with us
            </h3>
          </div>
          <.link
            navigate="/contact"
            class="mt-6 inline-block rounded-lg bg-blue-600 py-4.5 text-center font-bold uppercase tracking-widest text-gray-50 transition-link duration-300 focus:duration-0 hover:bg-blue-700 hover:duration-300 focus:outline-none focus-visible:ring-4 focus-visible:ring-blue-200 focus-visible:duration-300 active:bg-blue-800 md:mt-0 md:px-14 lg:w-auto lg:px-16 xl:px-20"
          >
            Start Your Project
          </.link>
        </div>
      </div>
      <%!-- Footer Links --%>
      <div class="xl:flex xl:justify-between max-w-7xl mx-auto">
        <nav class="md:pt-10 lg:pt-12 xl:basis-2/3 xl:pt-15 pt-8" aria-label="Footer">
          <div class="md:flex md:justify-between">
            <div class="md:mb-0 basis-5/12 mb-10">
              <%!-- Services --%>
              <h3 class="text-eyebrow tracking-widestXl lg:mb-5 lg:text-sm xl:mb-6 mb-4 font-medium text-gray-200 uppercase">
                <.link class="link-footer" navigate="/services">
                  Services
                </.link>
              </h3>
              <ul class="space-y-3 font-medium lg:space-y-4.5 lg:text-lg">
                <li>
                  <.link class="link-footer" navigate="/services/digital-product-strategy">
                    Product Strategy & Discovery
                  </.link>
                </li>
                <li>
                  <.link class="link-footer" navigate="/services/design">
                    Product Design & Delivery
                  </.link>
                </li>
                <li>
                  <.link class="link-footer" navigate="/services/engineering">
                    Engineering Consulting & Staffing
                  </.link>
                </li>
                <li>
                  <.link class="link-footer" navigate="/capabilities/elixir-consulting">
                    Elixir
                  </.link>
                </li>
                <li>
                  <.link class="link-footer" navigate="/why-dockyard">
                    Why DockYard?
                  </.link>
                </li>
              </ul>
            </div>
            <%!-- Company & Our Work --%>
            <div class="md:col-span-2 md:justify-between basis-7/12 grid grid-cols-2">
              <div>
                <h3 class="text-eyebrow tracking-widestXl lg:mb-5 lg:text-sm xl:mb-6 mb-4 font-medium text-gray-200 uppercase">
                  Company
                </h3>
                <ul class="space-y-3 font-medium lg:space-y-4.5 lg:text-lg">
                  <li>
                    <.link class="link-footer" navigate="/blog">
                      Blog
                    </.link>
                  </li>
                  <li>
                    <.link class="link-footer" navigate="/culture">
                      Culture
                    </.link>
                  </li>
                  <li>
                    <.link class="link-footer" navigate="/team">
                      Team
                    </.link>
                  </li>
                  <li>
                    <.link class="link-footer" navigate="/careers">
                      Careers
                    </.link>
                  </li>
                  <li>
                    <.link class="link-footer" navigate="/press/releases">
                      Newsroom
                    </.link>
                  </li>
                </ul>
              </div>
              <div>
                <h3 class="text-eyebrow tracking-widestXl lg:mb-5 lg:text-sm xl:mb-6 mb-4 font-medium text-gray-200 uppercase">
                  <.link class="link-footer" navigate="/work">
                    Our Work
                  </.link>
                </h3>
                <ul class="space-y-3 font-medium lg:space-y-4.5 lg:text-lg">
                  <li>
                    <.link class="link-footer" navigate="/work/case-studies/veeps">
                      Veeps
                    </.link>
                  </li>
                  <li>
                    <.link class="link-footer" navigate="/work/case-studies/mcgraw-hill-education">
                      McGraw-Hill
                    </.link>
                  </li>
                  <li>
                    <.link class="link-footer" navigate="/work/case-studies/netflix-scheduling">
                      Netflix Scheduling
                    </.link>
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </nav>
        <%!-- Social Media --%>
        <div class="mt-15 lg:mt-16 xl:-order-1">
          <div>
            <.link class="transition-link focus-within:outline-none focus-visible:ring-2 focus-visible:ring-blue-200 focus-visible:ring-offset-gray-700 focus-visible:duration-300 ring-offset-8 focus:duration-0 inline-block duration-200 rounded" navigate="/" aria-label="DockYard Home">
              <svg width="155" height="40" viewBox="0 0 155 40" fill="none" xmlns="http://www.w3.org/2000/svg" aria-label="DockYard Home">
                <title>DockYard Home</title>
                <g clip-path="url(#clip0_1005_8603)">
                  <path
                    d="M18.3446 0.0606346C14.2739 0.370419 10.3174 1.98998 7.14348 4.65303C3.71957 7.52259 1.29022 11.5987 0.41522 15.9356C-0.921737 22.5878 1.07283 29.3269 5.79566 34.1041C9.88261 38.2346 15.5022 40.3541 21.3065 39.9465C23.3065 39.8052 25.1326 39.3867 27.2576 38.5878C27.7359 38.403 29.062 37.7672 29.6381 37.4411C31.1761 36.5606 32.4207 35.6204 33.7196 34.3541C35.3717 32.74 36.5022 31.2128 37.562 29.1585C38.6761 26.9954 39.3663 24.7074 39.6544 22.2019C39.7848 21.0824 39.7848 18.9193 39.6544 17.7998C39.2304 14.1204 37.8826 10.7509 35.687 7.85411C34.5565 6.36498 33.0348 4.88129 31.4641 3.73998C29.9098 2.60955 27.8337 1.5552 25.9804 0.951939C23.6272 0.196503 20.8663 -0.129581 18.3446 0.0606346ZM31.3609 8.0389C31.3609 8.09324 31.1272 8.37585 30.5728 9.00085C29.3228 10.403 28.7522 11.0443 28.0457 11.8215C27.2631 12.6856 26.975 13.0009 26.1978 13.8324C25.975 14.0715 25.7141 14.3541 25.6163 14.4574L25.4424 14.6476L25.5783 15.0769C25.6489 15.3161 25.7685 15.8378 25.8283 16.2454C25.937 16.9085 25.9478 17.1911 25.9478 18.9411C25.9478 20.5389 25.9261 21.1313 25.8228 22.1748C25.5348 25.2182 25.1435 26.5117 24.225 27.49C22.9913 28.7943 21.2848 29.3269 17.6815 29.5226C15.9913 29.6096 13.9207 29.4846 12.5837 29.2128C10.725 28.8324 9.71414 27.8922 8.91522 25.8269C8.80653 25.5498 8.73044 25.4465 8.52935 25.2998C8.02392 24.9356 7.79022 24.4411 7.73587 23.6259L7.70327 23.153H7.86087C8.12718 23.153 8.57827 23.4085 8.9424 23.7563L9.29022 24.0878L9.64348 23.7672C10.0457 23.3976 10.5185 23.115 10.5728 23.2128C10.6489 23.3324 10.6707 24.1802 10.6054 24.4411C10.5674 24.5824 10.4478 24.8432 10.3446 25.0226L10.1489 25.3432L10.2739 25.5824C10.4424 25.8976 10.8935 26.3052 11.2902 26.4954C11.5294 26.6096 11.7141 26.653 12.0674 26.6748C12.638 26.7074 12.9967 26.6313 13.513 26.3867C14.4967 25.9139 15.1054 24.8922 15.3881 23.2346C15.5022 22.5606 15.6326 20.9193 15.6815 19.5389C15.7631 17.3596 16.0946 15.8541 16.7576 14.7019C17.0837 14.1422 17.7957 13.4519 18.3446 13.1693C19.687 12.4791 21.6163 12.3541 23.2304 12.865C23.4696 12.9411 23.7359 13.0389 23.8228 13.0824C23.9913 13.1639 23.8011 13.2835 25.5185 12.0226C26.6163 11.2182 29.2739 9.31064 30.2359 8.63129C31.062 8.0552 31.3609 7.89759 31.3609 8.0389Z"
                    fill="#F0F5F9"
                  />
                  <path d="M20.5442 15.4457C20.2561 15.6413 20.1094 15.8967 20.1094 16.1957C20.1094 16.8315 20.7833 17.25 21.3539 16.962C21.7833 16.7391 21.9463 16.2609 21.7289 15.8315C21.5659 15.4946 21.3757 15.3696 21.0224 15.337C20.7833 15.3207 20.7018 15.337 20.5442 15.4457Z" fill="#F0F5F9" />
                  <path
                    d="M20.0815 21.4612C18.7772 21.847 18.2283 22.4775 17.4837 24.4666C17.3207 24.896 17.1359 25.3471 17.0707 25.4775C16.962 25.6894 16.5435 26.2166 16.1794 26.6025C16.0979 26.6894 15.9674 26.8688 15.8913 26.9884C15.7772 27.184 15.7663 27.2329 15.8207 27.3579C15.9022 27.5318 16.2283 27.6949 16.6848 27.7764C16.9837 27.8308 17.1142 27.8253 17.4892 27.7492C18.0055 27.646 18.2174 27.559 18.6413 27.2764C19.2555 26.8688 19.5761 26.3742 20.0055 25.1568C20.375 24.1188 20.4674 23.9231 20.8642 23.2927C21.6685 22.0155 21.75 21.6351 21.2772 21.434C21.0272 21.3307 20.4837 21.3416 20.0815 21.4612Z"
                    fill="#F0F5F9"
                  />
                  <path
                    d="M69.2432 13.1918C66.7541 13.5287 64.6182 15.2298 63.7867 17.5504C63.4769 18.4091 63.4117 18.8548 63.4062 20.0015C63.4062 21.1754 63.4823 21.6754 63.803 22.545C64.5095 24.4852 66.091 26.0287 68.0476 26.6863C69.7813 27.2733 71.9497 27.0613 73.5095 26.1646C75.9606 24.7515 77.2378 22.2026 76.966 19.2841C76.8791 18.3928 76.6889 17.7026 76.3139 16.9309C75.3954 15.0505 73.7378 13.7515 71.6617 13.2896C71.2813 13.2026 69.6399 13.1374 69.2432 13.1918ZM71.4443 15.045C73.2704 15.5396 74.5965 16.8439 75.1236 18.6754C75.2323 19.0504 75.2486 19.2244 75.2486 20.0831C75.2486 21.007 75.2378 21.0885 75.091 21.5504C74.5367 23.295 73.3356 24.4907 71.6236 25.0015C71.0747 25.17 69.7704 25.2135 69.178 25.0885C67.8465 24.8167 66.6236 23.9635 65.9117 22.8222C65.6019 22.3167 65.4171 21.882 65.2649 21.2624C65.1019 20.5994 65.1019 19.5178 65.2649 18.8439C65.7541 16.8494 67.3139 15.3494 69.2867 14.9744C69.841 14.8711 70.928 14.9037 71.4443 15.045Z"
                    fill="#F0F5F9"
                  />
                  <path
                    d="M85.5456 13.191C82.6705 13.5768 80.426 15.6692 79.8064 18.5334C79.7303 18.8866 79.7031 19.229 79.7031 20.0008C79.7031 20.7725 79.7303 21.1149 79.8064 21.4681C80.3607 24.0334 82.2086 25.9845 84.7032 26.6421C85.3227 26.8051 85.4097 26.8105 86.4151 26.816C87.5238 26.8214 87.8662 26.7779 88.6978 26.5116C89.138 26.3703 89.9478 25.9845 89.9804 25.9029C89.9912 25.8649 89.9967 25.4301 89.9912 24.9301L89.9749 24.0225L89.676 24.2345C89.2086 24.566 88.5456 24.8758 87.9586 25.0334C87.4695 25.1692 87.3336 25.1855 86.5238 25.1801C85.7793 25.1801 85.5564 25.1584 85.1923 25.0605C83.3173 24.5551 81.9368 23.0714 81.5129 21.1149C81.4151 20.6584 81.4314 19.316 81.5401 18.8268C81.7629 17.8323 82.1977 17.0442 82.9151 16.3214C83.9695 15.2671 85.2412 14.7834 86.7684 14.854C87.801 14.9029 88.6651 15.1801 89.5075 15.729L89.9478 16.0225V15.0279V14.0388L89.5293 13.8431C88.5238 13.3703 87.7956 13.2073 86.6053 13.1801C86.1271 13.1692 85.6488 13.1747 85.5456 13.191Z"
                    fill="#F0F5F9"
                  />
                  <path
                    d="M105.236 13.3816C105.258 13.4414 106.404 15.3979 107.845 17.8273C108.084 18.2294 108.567 19.0501 108.921 19.6534L109.567 20.7457V23.7186V26.6914L110.399 26.6751L111.225 26.6588L111.252 23.6968L111.279 20.7349L111.448 20.4631C111.54 20.311 112.138 19.311 112.774 18.2349C114.486 15.3381 115.502 13.6316 115.589 13.4903L115.665 13.3707H114.687H113.709L113.252 14.1697C112.877 14.8273 111.589 17.0447 110.6 18.7457C110.486 18.936 110.383 19.0664 110.372 19.0447C110.355 19.0175 109.665 17.811 108.834 16.3599C108.002 14.9088 107.263 13.6316 107.192 13.5175L107.067 13.3164H106.138C105.415 13.3164 105.214 13.3327 105.236 13.3816Z"
                    fill="#F0F5F9"
                  />
                  <path
                    d="M121.052 13.3828C121.025 13.4209 120.922 13.66 120.829 13.9154C120.596 14.5622 119.726 16.8991 119.014 18.8067C117.106 23.9372 116.145 26.535 116.145 26.5839C116.145 26.6111 116.541 26.6328 117.063 26.6328H117.981L118.302 25.7469C118.481 25.2632 118.786 24.4317 118.976 23.8991L119.318 22.9372H121.992H124.666L125.03 23.9263C125.231 24.4752 125.519 25.2524 125.666 25.6546C125.813 26.0567 125.954 26.4426 125.981 26.5078C126.03 26.6328 126.052 26.6328 126.965 26.6328C127.824 26.6328 127.894 26.6274 127.867 26.535C127.856 26.4861 127.09 24.4372 126.172 21.9861C124.742 18.1546 123.036 13.6056 122.954 13.3828C122.932 13.3339 122.693 13.3176 122.014 13.3176C121.351 13.3176 121.09 13.3339 121.052 13.3828ZM122.612 17.2306C122.911 18.0513 123.204 18.8448 123.264 18.9969C123.552 19.7578 124.079 21.2143 124.079 21.2578C124.079 21.285 123.231 21.3067 121.987 21.3067H119.894L119.976 21.1002C120.019 20.9915 120.199 20.5078 120.373 20.0296C120.547 19.5513 120.981 18.3719 121.34 17.41C121.693 16.4426 122.003 15.6763 122.025 15.698C122.047 15.7198 122.307 16.41 122.612 17.2306Z"
                    fill="#F0F5F9"
                  />
                  <path
                    d="M49.5664 20.0008V26.6367L52.4632 26.615C55.5827 26.5932 55.5447 26.5932 56.5447 26.2726C58.6806 25.5878 60.1099 23.8541 60.5773 21.3867C60.7077 20.7074 60.7077 19.2889 60.5719 18.5878C60.1262 16.2237 58.7567 14.528 56.686 13.778C55.6643 13.4139 55.6371 13.4085 52.4632 13.3867L49.5664 13.365V20.0008ZM55.2512 15.0498C56.7023 15.3487 57.7566 16.1748 58.398 17.5117C58.811 18.3758 58.8871 18.7671 58.8871 20.0008C58.8817 21.1585 58.8436 21.4193 58.5338 22.2237C58.2295 23.0063 57.6208 23.8052 56.9903 24.2345C56.6208 24.49 56.0121 24.7672 55.5175 24.903C55.1153 25.0117 54.9414 25.0226 53.1697 25.0443L51.2512 25.0606V20.0063V14.9465H53.0066C54.5012 14.9465 54.8273 14.9628 55.2512 15.0498Z"
                    fill="#F0F5F9"
                  />
                  <path
                    d="M94.0343 20.0113L94.0506 26.6581H94.8658H95.681L95.6973 24.4896L95.7082 22.3211L96.5289 21.2994C96.9799 20.7341 97.3712 20.2722 97.3984 20.2722C97.4256 20.2722 97.5125 20.4026 97.5886 20.5548C97.6701 20.7124 97.9799 21.3048 98.2897 21.8755C98.5941 22.4407 99.2571 23.6798 99.7625 24.62C100.263 25.5602 100.714 26.4026 100.763 26.495L100.855 26.6581L101.839 26.6744C102.382 26.6798 102.828 26.6689 102.828 26.6526C102.828 26.6092 102.349 25.707 101.442 24.0494C101.197 23.5983 100.915 23.0874 100.817 22.9081C100.719 22.7287 100.181 21.7341 99.6158 20.6961L98.5886 18.8102L100.599 16.1146C101.703 14.6363 102.61 13.4081 102.61 13.3972C102.61 13.3809 102.165 13.37 101.621 13.3754H100.627L98.7245 15.8809C97.681 17.2613 96.5723 18.7178 96.268 19.12L95.7082 19.8537V16.6091V13.37H94.8658H94.0234L94.0343 20.0113Z"
                    fill="#F0F5F9"
                  />
                  <path
                    d="M131.086 20.0024V26.6328H131.928H132.771V23.8556V21.0785L133.711 21.1002C134.521 21.1219 134.684 21.1383 134.934 21.2415C136.042 21.698 136.994 22.9209 137.629 24.6926C137.782 25.1219 138.021 25.9915 138.124 26.4806L138.151 26.6328H139.026C139.831 26.6328 139.896 26.6274 139.869 26.535C139.858 26.4861 139.803 26.2361 139.754 25.9806C139.45 24.4643 138.863 23.0133 138.157 22.0404C137.776 21.5241 137.211 20.9535 136.836 20.7252C136.521 20.5296 136.477 20.4372 136.7 20.4372C136.76 20.4372 137.042 20.3285 137.32 20.1926C138.244 19.7415 138.896 18.9046 139.108 17.8828C139.211 17.3991 139.184 16.5133 139.042 16.0078C138.798 15.0839 138.113 14.2741 137.227 13.8448C136.331 13.4046 136.064 13.372 133.385 13.372H131.086V20.0024ZM136.015 15.1111C136.667 15.372 137.097 15.7904 137.314 16.3828C137.461 16.7741 137.461 17.6926 137.314 18.073C137.097 18.6383 136.673 19.0622 136.097 19.2904C135.684 19.4535 134.95 19.5187 133.803 19.5024L132.798 19.4861L132.782 17.2143L132.771 14.9426L134.222 14.9589C135.619 14.9752 135.689 14.9861 136.015 15.1111Z"
                    fill="#F0F5F9"
                  />
                  <path
                    d="M143.641 20.0024V26.6328H146.325C148.711 26.6328 149.075 26.6219 149.597 26.5296C151.63 26.1763 153.141 25.0785 154.016 23.323C154.999 21.3556 155.01 18.6872 154.037 16.7198C153.168 14.9426 151.646 13.8285 149.597 13.4752C149.075 13.3828 148.711 13.372 146.325 13.372H143.641V20.0024ZM149.325 15.0513C150.282 15.247 150.896 15.573 151.581 16.2524C152.054 16.7198 152.304 17.0893 152.575 17.7198C152.842 18.3448 152.94 18.8665 152.972 19.8122C152.994 20.5622 152.983 20.7578 152.885 21.2469C152.488 23.16 151.358 24.4154 149.592 24.9046C149.19 25.0132 149.016 25.0241 147.217 25.0459L145.271 25.0622V20.0078V14.948H147.054C148.575 14.948 148.902 14.9643 149.325 15.0513Z"
                    fill="#F0F5F9"
                  />
                </g>
                <defs>
                  <clipPath id="clip0_1005_8603">
                    <rect width="155" height="40" fill="white" />
                  </clipPath>
                </defs>
              </svg>
            </.link>
          </div>
          <div class="md:mt-12 lg:mt-15 xl:mt-16 mt-10 -ml-3">
            <ul class="flex items-center gap-x-0.5 text-gray-300 [&>li]:inline-block">
              <li>
                <a
                  class="group transition-link focus-within:outline-none focus-visible:ring-2 focus-visible:ring-blue-200 focus-visible:duration-300 inline-block p-3 rounded duration-200 focus:duration-0"
                  href="https://youtube.com/DockYard"
                  aria-label="DockYard on YouTube"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" aria-label="DockYard on YouTube">
                    <title>DockYard on YouTube</title>
                    <path fill="none" d="M0 0h24v24H0z" />
                    <path
                      class="transition-link group-hover:fill-blue-500 group-active:fill-blue-500 duration-200 fill-current"
                      d="M21.543 6.498C22 8.28 22 12 22 12s0 3.72-.457 5.502c-.254.985-.997 1.76-1.938 2.022C17.896 20 12 20 12 20s-5.893 0-7.605-.476c-.945-.266-1.687-1.04-1.938-2.022C2 15.72 2 12 2 12s0-3.72.457-5.502c.254-.985.997-1.76 1.938-2.022C6.107 4 12 4 12 4s5.896 0 7.605.476c.945.266 1.687 1.04 1.938 2.022zM10 15.5l6-3.5-6-3.5v7z"
                    />
                  </svg>
                </a>
              </li>
              <li>
                <a
                  class="group transition-link focus-within:outline-none focus-visible:ring-2 focus-visible:ring-blue-200 focus-visible:duration-300 inline-block p-3 rounded duration-200 focus:duration-0"
                  href="https://twitter.com/dockyard"
                  aria-label="DockYard on Twitter"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" aria-label="DockYard on Twitter">
                    <title>DockYard on Twitter</title>
                    <path fill="none" d="M0 0h24v24H0z" />
                    <path
                      class="transition-link group-hover:fill-blue-500 group-active:fill-blue-500 duration-200 fill-current"
                      d="M22.162 5.656a8.384 8.384 0 0 1-2.402.658A4.196 4.196 0 0 0 21.6 4c-.82.488-1.719.83-2.656 1.015a4.182 4.182 0 0 0-7.126 3.814 11.874 11.874 0 0 1-8.62-4.37 4.168 4.168 0 0 0-.566 2.103c0 1.45.738 2.731 1.86 3.481a4.168 4.168 0 0 1-1.894-.523v.052a4.185 4.185 0 0 0 3.355 4.101 4.21 4.21 0 0 1-1.89.072A4.185 4.185 0 0 0 7.97 16.65a8.394 8.394 0 0 1-6.191 1.732 11.83 11.83 0 0 0 6.41 1.88c7.693 0 11.9-6.373 11.9-11.9 0-.18-.005-.362-.013-.54a8.496 8.496 0 0 0 2.087-2.165z"
                    />
                  </svg>
                </a>
              </li>
              <li>
                <a
                  class="group transition-link focus-within:outline-none focus-visible:ring-2 focus-visible:ring-blue-200 focus-visible:duration-300 inline-block p-3 rounded duration-200 focus:duration-0"
                  href="https://www.linkedin.com/company/dockyard"
                  aria-label="DockYard on LinkedIn"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" aria-label="DockYard on LinkedIn">
                    <title>DockYard on LinkedIn</title>
                    <path fill="none" d="M0 0h24v24H0z" />
                    <path class="transition-link group-hover:fill-blue-500 group-active:fill-blue-500 duration-200 fill-current" d="M6.94 5a2 2 0 1 1-4-.002 2 2 0 0 1 4 .002zM7 8.48H3V21h4V8.48zm6.32 0H9.34V21h3.94v-6.57c0-3.66 4.77-4 4.77 0V21H22v-7.93c0-6.17-7.06-5.94-8.72-2.91l.04-1.68z" />
                  </svg>
                </a>
              </li>
              <li>
                <a
                  class="group transition-link focus-within:outline-none focus-visible:ring-2 focus-visible:ring-blue-200 focus-visible:duration-300 focus:duration-0 inline-block p-3 duration-200 rounded"
                  href="https://dribbble.com/dockyard"
                  aria-label="DockYard on Dribbble"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" aria-label="DockYard on Dribbble">
                    <title>DockYard on Dribbble</title>
                    <path fill="none" d="M0 0h24v24H0z" />
                    <path
                      class="transition-link group-hover:fill-blue-500 group-active:fill-blue-500 duration-200 fill-current"
                      d="M19.989 11.572a7.96 7.96 0 0 0-1.573-4.351 9.749 9.749 0 0 1-.92.87 13.157 13.157 0 0 1-3.313 2.01c.167.35.32.689.455 1.009v.003a9.186 9.186 0 0 1 .11.27c1.514-.17 3.11-.108 4.657.101.206.028.4.058.584.088zm-9.385-7.45a46.164 46.164 0 0 1 2.692 4.27c1.223-.482 2.234-1.09 3.048-1.767a7.88 7.88 0 0 0 .796-.755A7.968 7.968 0 0 0 12 4a8.05 8.05 0 0 0-1.396.121zM4.253 9.997a29.21 29.21 0 0 0 2.04-.123 31.53 31.53 0 0 0 4.862-.822 54.365 54.365 0 0 0-2.7-4.227 8.018 8.018 0 0 0-4.202 5.172zm1.53 7.038c.388-.567.898-1.205 1.575-1.899 1.454-1.49 3.17-2.65 5.156-3.29l.062-.018c-.165-.364-.32-.689-.476-.995-1.836.535-3.77.869-5.697 1.042-.94.085-1.783.122-2.403.128a7.967 7.967 0 0 0 1.784 5.032zm9.222 2.38a35.947 35.947 0 0 0-1.632-5.709c-2.002.727-3.597 1.79-4.83 3.058a9.77 9.77 0 0 0-1.317 1.655A7.964 7.964 0 0 0 12 20a7.977 7.977 0 0 0 3.005-.583zm1.873-1.075a7.998 7.998 0 0 0 2.987-4.87c-.34-.085-.771-.17-1.245-.236a12.023 12.023 0 0 0-3.18-.033 39.368 39.368 0 0 1 1.438 5.14zM12 22C6.477 22 2 17.523 2 12S6.477 2 12 2s10 4.477 10 10-4.477 10-10 10z"
                    />
                  </svg>
                </a>
              </li>
              <li>
                <a
                  class="group transition-link focus-within:outline-none focus-visible:ring-2 focus-visible:ring-blue-200 focus-visible:duration-300 focus:duration-0 inline-block p-3 duration-200 rounded"
                  href="https://github.com/dockyard"
                  aria-label="DockYard on GitHub"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" aria-label="DockYard on GitHub">
                    <title>DockYard on GitHub</title>
                    <path fill="none" d="M0 0h24v24H0z" />
                    <path
                      class="transition-link group-hover:fill-blue-500 group-active:fill-blue-500 duration-200 fill-current"
                      d="M12 2C6.475 2 2 6.475 2 12a9.994 9.994 0 0 0 6.838 9.488c.5.087.687-.213.687-.476 0-.237-.013-1.024-.013-1.862-2.512.463-3.162-.612-3.362-1.175-.113-.288-.6-1.175-1.025-1.413-.35-.187-.85-.65-.013-.662.788-.013 1.35.725 1.538 1.025.9 1.512 2.338 1.087 2.912.825.088-.65.35-1.087.638-1.337-2.225-.25-4.55-1.113-4.55-4.938 0-1.088.387-1.987 1.025-2.688-.1-.25-.45-1.275.1-2.65 0 0 .837-.262 2.75 1.026a9.28 9.28 0 0 1 2.5-.338c.85 0 1.7.112 2.5.337 1.912-1.3 2.75-1.024 2.75-1.024.55 1.375.2 2.4.1 2.65.637.7 1.025 1.587 1.025 2.687 0 3.838-2.337 4.688-4.562 4.938.362.312.675.912.675 1.85 0 1.337-.013 2.412-.013 2.75 0 .262.188.574.688.474A10.016 10.016 0 0 0 22 12c0-5.525-4.475-10-10-10z"
                    />
                  </svg>
                </a>
              </li>
            </ul>
          </div>
          <p class="font-heading text-eyebrow lg:mt-4 mt-3 font-semibold text-gray-200">
            Copyright <%= DateTime.utc_now().year %>. DockYard Inc. All Rights Reserved
          </p>
          <.link class="font-heading text-eyebrow lg:mt-3 link-footer block mt-2 font-semibold text-gray-200" navigate="/terms-of-service-and-privacy-policy">
            Terms of Service and Privacy Policy
          </.link>
        </div>
      </div>
    </footer>
    """
  })

  layout =
    Beacon.Content.create_layout!(%{
      site: "dy",
      title: "main",
      template: """
      <%= my_component("header", []) %>
      <%= @inner_content %>
      <%= my_component("footer", []) %>
      """
    })

  Beacon.Content.publish_layout(layout)

  page_home =
    Beacon.Content.create_page!(%{
      path: "/",
      site: "dy",
      title: "home",
      description: "home",
      layout_id: layout.id,
      template: """
      <main class="font-body text-gray-900">
        <%!-- Intro --%>
        <section aria-labelledby="region01">
          <div class="xl:pb-0 relative flex flex-col pb-5">
            <%!-- Intro text absolute position --%>
            <div class="xl:absolute xl:top-10 xl:left-0 xl:w-full 2xl:top-20 px-4">
              <div class="flex flex-col max-w-4xl mx-auto text-center">
                <%!-- Intro headings --%>
                <div class="sm:absolute sm:top-10 sm:left-0 sm:w-full xl:static xl:top-auto xl:left-auto flex flex-col">
                  <h1 class="font-heading lg:text-4xl lg:leading-normal xl:text-5xl xl:leading-normal mb-3 text-3xl leading-normal" id="region01">
                    Hi. We’re a
                    <span class="to-dy-gradient-pink bg-clip-text bg-gradient-to-r from-blue-500 font-bold text-transparent">
                      digital product consultancy.
                    </span>
                  </h1>
                  <h2 class="-order-1 md:text-base md:leading-7 lg:mb-5 lg:text-lg xl:mb-6 xl:text-xl xl:leading-8 mb-3 text-sm font-semibold leading-6">
                    Growth, Uninhibited
                  </h2>
                </div>
                <%!-- Intro text --%>
                <div>
                  <p class="lg:mb-12 lg:text-2xl lg:leading-loose xl:mb-15 mb-10 text-xl leading-8">
                    We partner with innovative teams to build products that scale
                    as their users, features, and complexity grow.
                  </p>
                  <.link class="link-default lg:bg-white/50 py-3 px-4" navigate="/contact/hire-us">
                    Get in Touch with Us
                  </.link>
                </div>
              </div>
            </div>
            <%!-- Intro image --%>
            <div class="-order-1">
              <%!-- TODO: update with finalized design image if provided --%>
              <img class="w-full h-auto" width="1920" height="1422" src="https://assets.dockyard.com/images/narwin-home-flare-v2.svg" alt="Narwin waving while standing in front of a vast horizon of ocean waves and mountains" />
            </div>
          </div>
          <%!-- Logos --%>
          <div class="md:py-18 py-15 lg:py-20 xl:pt-0 px-4">
            <div class="md:mb-12 lg:mb-16 xl:mb-20 max-w-6xl mx-auto mb-10">
              <ul class="md:grid-cols-3 md:gap-10 lg:grid-cols-4 lg:gap-20 grid items-center grid-cols-2 gap-8">
                <li class="basis-1/2 grow-0 shrink flex justify-center h-8">
                  <img class="w-auto h-full" src="https://assets.dockyard.com/images/client_apple.svg" width="122" height="150" alt="Apple" />
                </li>
                <li class="basis-1/2 grow-0 shrink flex justify-center h-8">
                  <img class="w-auto h-full" src="https://assets.dockyard.com/images/client-nasdaq-new.svg" width="168" height="48" alt="Nasdaq" />
                </li>
                <li class="basis-1/2 grow-0 shrink flex justify-center h-8">
                  <img class="w-auto h-full" src="https://assets.dockyard.com/images/client_netflix.svg" width="300" height="80" alt="Netflix" />
                </li>
                <li class="basis-1/2 grow-0 shrink flex justify-center h-8">
                  <img class="w-auto h-full" src="https://assets.dockyard.com/images/client-adobe.svg" width="54" height="14" alt="Adobe" />
                </li>
                <li class="basis-1/2 grow-0 shrink flex justify-center h-8">
                  <img class="w-auto h-full" src="https://assets.dockyard.com/images/client_mcgraw-hill.svg" width="150" height="150" alt="McGraw Hill" />
                </li>
                <li class="basis-1/2 grow-0 shrink flex justify-center h-8">
                  <img class="w-auto h-full" src="https://assets.dockyard.com/images/client-livenation.svg" width="1302" height="277" alt="Live Nation" />
                </li>
                <li class="basis-1/2 grow-0 shrink flex justify-center h-8">
                  <img class="w-auto h-full" src="https://assets.dockyard.com/images/client-collegevine-new.svg" width="147" height="32" alt="CollegeVine" />
                </li>
                <li class="basis-1/2 grow-0 shrink flex justify-center h-6">
                  <img class="w-auto h-full" src="https://assets.dockyard.com/images/client-constant-contact-new.svg" width="332" height="57" alt="Constant Contact" />
                </li>
              </ul>
            </div>
            <div class="max-w-5xl mx-auto">
              <p class="font-heading lg:text-2xl lg:leading-loose text-xl font-medium leading-8 text-center">
                For more than a decade, Fortune 500s and industry disruptors have
                trusted us to help them overcome complex product challenges and
                bring products from idea to impact.
              </p>
            </div>
          </div>
        </section>
        <%!-- Services --%>
        <section class="py-15 md:py-20 lg:py-24 xl:py-30 bg-gray-50 px-4" aria-labelledby="region02">
          <div class="max-w-1200 md:grid md:grid-cols-5 md:gap-x-10 lg:gap-x-20 xl:gap-x-30 mx-auto">
            <div class="mb-15 md:col-span-2 md:mb-0">
              <h2 class="font-heading md:text-4xl lg:text-5xl xl:text-6xl mb-4 text-3xl font-extrabold" id="region02">
                How we help
              </h2>
              <p class="lg:mb-12 mb-10 text-xl leading-8 text-gray-800">
                We pair modern technologies with design thinking to turn user
                insights into production-ready apps (and mentor teams along the
                way).
              </p>
              <.link class="link-default link-default--gray-50" navigate="/services">
                See All Services
              </.link>
            </div>
            <ul class="md:col-span-3 md:-my-4 xl:-my-10 xl:-mx-10 xl:-space-y-5 -mx-4">
              <li class="transition-link focus-within:bg-white focus-within:ring-2 focus-within:ring-blue-200 hover:bg-white active:bg-white xl:p-10 rounded-2xl relative block p-4 duration-300">
                <h3 class="font-heading lg:text-2xl lg:leading-normal xl:text-3xl xl:leading-normal mb-2 text-xl font-medium leading-8">
                  <.link class="after:absolute after:inset-0 after:cursor-pointer focus:outline-none" navigate="/services/digital-product-strategy">
                    Product Strategy & Discovery
                  </.link>
                </h3>
                <p class="lg:text-lg lg:leading-loose leading-7 text-gray-800">
                  We guide clients – uncovering user needs and aligning business
                  goals – to make sure products are on the right path. Then, we
                  create a product roadmap that sets the stage for successful
                  delivery.
                </p>
              </li>
              <li class="transition-link focus-within:bg-white focus-within:ring-2 focus-within:ring-blue-200 hover:bg-white active:bg-white xl:p-10 rounded-2xl relative block p-4 duration-300">
                <h3 class="font-heading lg:text-2xl lg:leading-normal xl:text-3xl xl:leading-normal mb-2 text-xl font-medium leading-8">
                  <.link class="after:absolute after:inset-0 after:cursor-pointer focus:outline-none" navigate="/services/design">
                    Product Design & Delivery
                  </.link>
                </h3>
                <p class="lg:text-lg lg:leading-loose leading-7 text-gray-800">
                  We take product visions and add design, UX, and engineering to
                  create the complete package — aka reliable, scalable,
                  sustainable, custom software that our clients and their users
                  will love.
                </p>
              </li>
              <li class="transition-link focus-within:bg-white focus-within:ring-2 focus-within:ring-blue-200 hover:bg-white active:bg-white xl:p-10 rounded-2xl relative block p-4 duration-300">
                <h3 class="font-heading lg:text-2xl lg:leading-normal xl:text-3xl xl:leading-normal mb-2 text-xl font-medium leading-8">
                  <.link class="after:absolute after:inset-0 after:cursor-pointer focus:outline-none" navigate="/services/engineering">
                    Engineering Consulting & Staffing
                  </.link>
                </h3>
                <p class="lg:text-lg lg:leading-loose leading-7 text-gray-800">
                  Accelerate time to product success with expert engineering
                  guidance — whether you need to augment your team, audit an
                  existing codebase, or train in a specific web technology.
                </p>
              </li>
            </ul>
          </div>
        </section>
        <%!-- Collaboration --%>
        <section aria-labelledby="big-on-collaboration" class="pb-15 md:pb-20 lg:pb-24 xl:pb-30 px-4">
          <div class="md:grid-cols-12 md:items-center md:gap-x-10 lg:gap-x-12 xl:gap-x-0 max-w-7xl grid mx-auto">
            <div class="xlg:col-end-13 md:col-span-6 xl:col-start-8">
              <h2 class="font-heading lg:text-3xl lg:leading-normal mb-4 text-2xl font-medium" id="big-on-collaboration">
                Big on collaboration, <br />Small on surprises
              </h2>
              <p class="lg:mb-12 lg:text-xl lg:leading-8 mb-10 text-lg leading-loose text-gray-700">
                We become an extension of your team using constant communication
                and knowledge sharing each step of the way.
              </p>
              <.link class="link-default" navigate="/why-dockyard">
                Why DockYard?
              </.link>
            </div>
            <div class="-order-1 md:col-span-6 md:mb-0 mb-10">
              <img class="w-full h-auto max-w-full" width="1087" height="755" src="https://assets.dockyard.com/images/narwin-f2f-meeting-og-v2.svg" alt="Narwin sitting at a table in a face-to-face meeting with two collaborators" loading="lazy" />
            </div>
          </div>
        </section>
        <%!-- Quote --%>
        <div class="py-15 md:pb-20 md:pt-24 lg:pb-24 lg:pt-30 xl:pb-30 px-4 bg-gray-100">
          <figure class="max-w-3xl mx-auto">
            <blockquote>
              <div class="lg:mb-8 xl:mb-10 mb-6 mx-auto lg:w-[56px] lg:h-[43px]">
                <svg class="w-auto h-full mx-auto" width="46" height="35" viewBox="0 0 46 35" fill="none" xmlns="http://www.w3.org/2000/svg" role="presentation">
                  <path
                    d="M4.4575 31.3007C1.8825 28.5657 0.5 25.4982 0.5 20.5257C0.5 11.7757 6.6425 3.93316 15.575 0.0556641L17.8075 3.50066C9.47 8.01066 7.84 13.8632 7.19 17.5532C8.5325 16.8582 10.29 16.6157 12.0125 16.7757C16.5225 17.1932 20.0775 20.8957 20.0775 25.4982C20.0775 27.8188 19.1556 30.0444 17.5147 31.6854C15.8737 33.3263 13.6481 34.2482 11.3275 34.2482C10.0441 34.2369 8.77584 33.9706 7.5964 33.4646C6.41697 32.9585 5.34997 32.223 4.4575 31.3007ZM29.4575 31.3007C26.8825 28.5657 25.5 25.4982 25.5 20.5257C25.5 11.7757 31.6425 3.93316 40.575 0.0556641L42.8075 3.50066C34.47 8.01066 32.84 13.8632 32.19 17.5532C33.5325 16.8582 35.29 16.6157 37.0125 16.7757C41.5225 17.1932 45.0775 20.8957 45.0775 25.4982C45.0775 27.8188 44.1556 30.0444 42.5147 31.6854C40.8737 33.3263 38.6481 34.2482 36.3275 34.2482C35.0441 34.2369 33.7758 33.9706 32.5964 33.4646C31.417 32.9585 30.35 32.223 29.4575 31.3007Z"
                    fill="#CAD5E0"
                  />
                </svg>
              </div>
              <p class="font-heading lg:text-left mb-8 text-2xl font-medium leading-10 text-center">
                It would be impossible for me to adequately sum up several years
                with DockYard that for me was a delight, source of growth, and
                tremendous learning experience. Overall my experience with the
                partnership was extremely positive.
              </p>
            </blockquote>
            <figcaption>
              <div class="gap-x-4 flex items-center justify-center">
                <div class="text-center">
                  <p class="text-lg font-bold leading-7 text-gray-800">Tim H.</p>
                  <p class="block text-sm text-gray-800">Netflix Studios</p>
                </div>
              </div>
            </figcaption>
          </figure>
        </div>
        <%!-- News --%>
        <section class="py-15 md:py-20 lg:py-24 xl:py-30 px-4" aria-labelledby="news">
          <div class="max-w-7xl mx-auto text-center">
            <svg class="md:mb-10 lg:mb-14 xl:mb-20 mx-auto mb-8" width="40" height="40" viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg" role="presentation">
              <path
                d="M35.9326 31.6743L37.8049 32.2551C38.8161 32.5678 39.7909 31.6703 39.5553 30.6346L37.5775 21.8987C37.3419 20.8671 36.0789 20.4731 35.2991 21.192L28.7238 27.2759C27.944 27.9947 28.2364 29.2863 29.2517 29.603L30.9656 30.1351C29.9422 31.3088 28.736 32.316 27.3876 33.112C25.8605 34.0136 24.1832 34.6269 22.4368 34.9193V20.331H26.6566C28.0009 20.331 29.0934 19.2386 29.0934 17.8942C29.0934 16.5499 28.0009 15.4574 26.6566 15.4574H22.4368V13.4471C25.0686 12.4561 26.9449 9.91777 26.9449 6.94487C26.9449 3.11504 23.8299 0 20 0C16.1702 0 13.0552 3.11504 13.0552 6.94487C13.0552 9.91777 14.9315 12.4602 17.5632 13.4471V15.4574H13.3435C11.9992 15.4574 10.9067 16.5499 10.9067 17.8942C10.9067 19.2386 11.9992 20.331 13.3435 20.331H17.5632V34.9193C15.8209 34.6228 14.1395 34.0136 12.6125 33.112C11.2682 32.3119 10.0579 31.3047 9.03444 30.131L10.7483 29.599C11.7596 29.2863 12.052 27.9947 11.2763 27.2718L4.701 21.192C3.92123 20.4732 2.65816 20.8671 2.4226 21.8987L0.444731 30.6386C0.209174 31.6702 1.18389 32.5719 2.19516 32.2591L4.06744 31.6783C5.65948 33.9608 7.73076 35.8859 10.131 37.3073C13.108 39.07 16.5235 40 20 40C23.4765 40 26.8881 39.07 29.8691 37.3073C32.2693 35.8819 34.3405 33.9568 35.9326 31.6743ZM22.0713 6.94081C22.0713 7.2576 21.9982 7.55814 21.8723 7.83024C21.5393 8.52879 20.8245 9.01209 20 9.01209C19.1756 9.01209 18.4608 8.52879 18.1278 7.83024C17.9978 7.5622 17.9288 7.26166 17.9288 6.94081C17.9288 5.79958 18.8588 4.86953 20 4.86953C21.1413 4.86953 22.0713 5.79958 22.0713 6.94081Z"
                fill="#CAD5E0"
              />
            </svg>
            <h2 class="font-heading lg:text-7xl lg:leading-none xl:text-8xl mx-auto mb-8 text-6xl font-extrabold leading-none" id="news">
              Share the news
            </h2>
            <div class="max-w-xl mx-auto">
              <p class="font-xl lg:mb-12 lg:text-2xl lg:leading-10 xl:mb-15 mb-10 leading-8">
                We have been featured in numerous publications and media since our
                inception a decade ago.
              </p>
              <a class="link-default" href="/press/releases">
                See News and Media
              </a>
            </div>
          </div>
        </section>
        <%!-- Product delivery success --%>
        <section class="bg-dy-purple-light py-15 md:py-20 lg:py-24 xl:py-30 px-4" aria-labelledby="product-delivery-success">
          <div class="mb-15 md:mb-12 lg:mb-10 xl:mb-6 max-w-lg mx-auto text-center">
            <h2 class="mb-5 text-3xl font-medium" id="product-delivery-success">
              Let's accelerate time to product <span class="text-dy-red line-through">delivery</span> success
            </h2>
            <p class="mb-8 text-xl leading-8 text-gray-700">
              Tell us what you’re looking for and how we can help.
            </p>
            <.link class="link-default link-default--purple" navigate="/contact/hire-us">
              Connect with Us
            </.link>
          </div>
          <div class="max-w-3xl mx-auto">
            <img class="w-full h-auto" src="https://assets.dockyard.com/images/narwin-trophy-flag-og-v2.svg" width="1067" height="881" alt="Narwin celebrating while holding a trophy for 'Product Success' and a DockYard flag" loading="lazy" />
          </div>
        </section>
      </main>
      """
    })

  Beacon.Content.publish_page(page_home)
end

dev_site = [
  site: :dev,
  endpoint: SamplePhoenix.Endpoint,
  skip_boot?: true,
  extra_page_fields: [BeaconTagsField],
  lifecycle: [upload_asset: [thumbnail: &Beacon.Lifecycle.Asset.thumbnail/2, _480w: &Beacon.Lifecycle.Asset.variant_480w/2]],
  default_meta_tags: [
    %{"name" => "default", "content" => "dev"}
  ]
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
       [site: :dy, endpoint: SamplePhoenix.Endpoint, skip_boot?: true]
     ]},
    SamplePhoenix.Endpoint
  ]

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

  # TODO: revert this change and remove ecto.reset from mix dev alias
  # Ecto.Migrator.with_repo(Beacon.Repo, &Ecto.Migrator.run(&1, :down, all: true))
  # Ecto.Migrator.with_repo(Beacon.Repo, &Ecto.Migrator.run(&1, :up, all: true))

  dev_seeds.()
  dy_seeds.()

  Beacon.boot(:dev)
  Beacon.boot(:dy)

  Process.sleep(:infinity)
end)
