defmodule Beacon.Loader.Worker do
  @moduledoc false

  use GenServer, restart: :transient
  require Logger
  alias Beacon.Compiler
  alias Beacon.Content
  alias Beacon.Loader

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  def name(site) do
    # starts an unique worker every time because we don't care about module dependencies
    # they are commpiled and loaded individually
    u = System.unique_integer([:positive])
    Beacon.Registry.via({site, __MODULE__, u})
  end

  def init(config) do
    {:ok, config}
  end

  def handle_call(:ping, _from, config) do
    stop(:pong, config)
  end

  def handle_call(:populate_default_components, _from, config) do
    %{site: site} = config

    for attrs <- Content.blueprint_components() do
      case Content.list_components_by_name(site, attrs.name) do
        [] ->
          attrs
          |> Map.put(:site, site)
          |> Content.create_component!()

        _ ->
          :skip
      end
    end

    stop(:ok, config)
  end

  def handle_call(:populate_default_layouts, _from, config) do
    %{site: site} = config

    case Content.get_layout_by(site, title: "Default") do
      nil ->
        Content.default_layout()
        |> Map.put(:site, site)
        |> Content.create_layout!()
        |> Content.publish_layout()

      _ ->
        :skip
    end

    stop(:ok, config)
  end

  def handle_call(:populate_default_error_pages, _from, config) do
    %{site: site} = config
    default_layout = Content.get_layout_by(site, title: "Default")

    populate = fn ->
      for attrs <- Content.default_error_pages() do
        case Content.get_error_page(site, attrs.status) do
          nil ->
            attrs
            |> Map.put(:site, site)
            |> Map.put(:layout_id, default_layout.id)
            |> Content.create_error_page!()

          _ ->
            :skip
        end
      end
    end

    if default_layout do
      populate.()
      stop(:ok, config)
    else
      Logger.error("failed to populate default error pages because the default layout is missing.")
      stop({:error, :missing_default_layout}, config)
    end
  end

  def handle_call(:populate_default_home_page, _from, config) do
    %{site: site} = config
    default_layout = Content.get_layout_by(site, title: "Default")

    populate = fn ->
      case Content.get_page_by(site, path: "/") do
        nil ->
          Content.create_stylesheet(%{
            site: site,
            name: "beacon-demo",
            content: ~S"""
            .beacon-demo-home {
                background: rgb(50,163,252);
                background: linear-gradient(145deg, rgba(50,163,252,1) 0%, rgba(99,102,241,1) 26%, rgba(138,55,214,1) 55%, rgba(100,37,181,1) 76%, rgba(31,41,55,1) 100%);
                background-size: 400% 400%;
                animation: beacon-demo-home-gradient 30s ease infinite;
                height: 100vh;
                font-family: "Plus Jakarta Sans", sans-serif;
            }

            @keyframes beacon-demo-home-gradient {
                0% {
                    background-position: 0% 0%;
                }
                50% {
                    background-position: 100% 100%;
                }
                100% {
                    background-position: 0% 0%;
                }
            }
            .beacon-demo-home-title {
                background: linear-gradient(
                    to right,
                    rgb(186, 230, 253),
                    rgb(221, 214, 254)
                );
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                text-shadow: 0 2px 4px rgba(255, 255, 255, 0.1);
            }
            """
          })

          %{
            site: site,
            layout_id: default_layout.id,
            path: "/",
            title: "My Home Page",
            template: ~S"""
            <div class="beacon-demo-home">
              <div class="text-white min-h-fit flex items-center justify-center">
                <div class="max-w-screen-lg w-full px-6 py-12">
                  <div class="text-center">
                    <h1 class="beacon-demo-home-title font-bold text-7xl mb-2">
                      Beacon
                    </h1>
                    <p class="mb-12 text-3xl">
                      Performance without compromising productivity
                    </p>
                  </div>

                  <div class="grid grid-cols-1 md:grid-cols-4 gap-6 text-sm">
                    <div class="p-4 bg-indigo-50 text-black border border-indigo-100 rounded-lg shadow-xl shadow-indigo-600/50 hover:border-sky-100 hover:shadow-sky-200/30 duration-1000">
                      <h2 class="pb-2 text-base font-bold">
                        SEO-friendly
                      </h2>
                      <p>
                        Out-of-the-box fast page rendering and high
                        scores, even with dynamic data.
                      </p>
                    </div>
                    <div class="p-4 bg-indigo-50 text-black border border-indigo-100 rounded-lg shadow-xl shadow-indigo-600/50 hover:border-sky-100 hover:shadow-sky-200/30 duration-1000">
                      <h2 class="pb-2 text-base font-bold">Practical</h2>
                      <p>
                        Updating your site is a click away, without slow
                        deployments.
                      </p>
                    </div>
                    <div class="p-4 bg-indigo-50 text-black border border-indigo-100 rounded-lg shadow-xl shadow-indigo-600/50 hover:border-sky-100 hover:shadow-sky-200/30 duration-1000">
                      <h2 class="pb-2 text-base font-bold">Scalable</h2>
                      <p>
                        Start serving thousands of requests and upgrade
                        to a cluster to go far beyond.
                      </p>
                    </div>
                    <div class="p-4 bg-indigo-50 text-black border border-indigo-100 rounded-lg shadow-xl shadow-indigo-600/50 hover:border-sky-100 hover:shadow-sky-200/30 duration-1000">
                      <h2 class="pb-2 text-base font-bold">
                        Open-Source
                      </h2>
                      <p>
                        Verify, contribute, and adapt to your needs. A
                        project for the community.
                      </p>
                    </div>
                  </div>

                  <div class="mt-16 leading-loose">
                    <h2 class="text-4xl font-bold mb-2">Features</h2>
                    <p class="mb-8">
                      Check out the
                      <a
                        href="https://github.com/BeaconCMS/beacon_demo"
                        class="text-sky-200 no-underline py-1 px-2 mx-1 border border-sky-600 shadow-lg shadow-sky-400/40 rounded-full hover:border-fuchsia-100 hover:shadow-fuchsia-300/40 duration-1000"
                      >
                        demo application
                      </a>
                      to learn about the features listed below. Run it,
                      change it, and deploy your site.
                    </p>

                    <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
                      <div class="py-2 pr-4">
                        <h2 class="mb-2 font-bold text-2xl">
                          Visual Page Builder
                        </h2>
                        <p>
                          Drag and drop HTML elements and Components
                          into your page template, and change
                          attributes and classes. Works with HTML and
                          HEEx templates.
                        </p>
                      </div>

                      <div class="py-2 pr-4">
                        <h2 class="mb-2 font-bold text-2xl">
                          Components
                        </h2>
                        <p>
                          Reuse Phoenix Components to speed up the
                          development of pages. Common components are
                          already integrated and you can create more.
                        </p>
                      </div>

                      <div class="py-2 pr-4">
                        <h2 class="mb-2 font-bold text-2xl">
                          Media Library
                        </h2>
                        <p>
                          Upload images, videos, documents, and
                          virtually any kind of media. Process the
                          files, store them in a cloud provider, and
                          render them in your pages.
                        </p>
                      </div>

                      <div class="py-2 pr-4">
                        <h2 class="mb-2 font-bold text-2xl">
                          Live Data
                        </h2>
                        <p>
                          Execute Elixir code to load data from your
                          app, third-party APIs, or any other source.
                          Updates are made available at runtime
                          without the need for deployments.
                        </p>
                      </div>

                      <div class="py-2 pr-4">
                        <h2 class="mb-2 font-bold text-2xl">
                          A/B Variants
                        </h2>
                        <p>
                          Create N versions of a page, and tell a
                          story in different perspectives and styles
                          to measure conversion. Each version has a
                          weight to be served more or less.
                        </p>
                      </div>

                      <div class="py-2 pr-4">
                        <h2 class="mb-2 font-bold text-2xl">
                          Error Pages
                        </h2>
                        <p>
                          Sometimes error happens but you can create
                          personalized and informative error pages to
                          guide your visitors back to finding the
                          right page and increase engagement.
                        </p>
                      </div>

                      <div class="py-2 pr-4">
                        <h2 class="mb-2 font-bold text-2xl">
                          Built-in TailwindCSS
                        </h2>
                        <p>
                          Start prototyping your site right away with
                          tailwind utility classes on the code editor
                          or the visual page builder. The compiler
                          generates compact assets to keep your site
                          fast.
                        </p>
                      </div>

                      <div class="py-2 pr-4">
                        <h2 class="mb-2 font-bold text-2xl">
                          And more...
                        </h2>
                        <p>
                          Much more is available: meta tags,
                          Schema.org support, authorization,
                          authentication, custom page fields, custom
                          admin pages, and more. Beacon is constantly
                          evolving.
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <footer class="text-center mt-6 w-full flex flex-col items-center text-sm font-bold text-sky-300 tracking-wide">
                <div class="flex justify-center items-center">
                  <a href="https://beaconcms.org" class="inline-block p-4 m-3 no-underline hover:underline hover:decoration-dashed underline-offset-4">
                    BeaconCMS.org
                  </a>
                  <a
                    href="https://github.com/BeaconCMS/beacon"
                    class="inline-block p-4 m-3 no-underline hover:underline hover:decoration-dashed underline-offset-4"
                  >
                    GitHub Repo
                  </a>
                </div>
              </footer>
            </div>
            """
          }
          |> Content.create_page!()
          |> Content.publish_page()

        _ ->
          :skip
      end
    end

    if default_layout do
      populate.()
      stop(:ok, config)
    else
      Logger.error("failed to populate default error pages because the default layout is missing.")
      stop({:error, :missing_default_layout}, config)
    end
  end

  def handle_call(:reload_snippets_module, _from, config) do
    %{site: site} = config
    snippets = Content.list_snippet_helpers(site)
    ast = Loader.Snippets.build_ast(site, snippets)
    stop(compile_module(site, ast), config)
  end

  def handle_call(:reload_components_module, _from, config) do
    %{site: site} = config
    components = Content.list_components(site, per_page: :infinity)
    ast = Loader.Components.build_ast(site, components)
    result = compile_module(site, ast)
    stop(result, config)
  end

  def handle_call(:reload_live_data_module, _from, config) do
    %{site: site} = config
    live_data = Content.live_data_for_site(site)
    ast = Loader.LiveData.build_ast(site, live_data)
    stop(compile_module(site, ast), config)
  end

  def handle_call(:reload_error_page_module, _from, config) do
    %{site: site} = config
    error_pages = Content.list_error_pages(site, preloads: [:layout])
    ast = Loader.ErrorPage.build_ast(site, error_pages)
    result = compile_module(site, ast)
    stop(result, config)
  end

  def handle_call(:reload_stylesheet_module, _from, config) do
    %{site: site} = config
    stylesheets = Content.list_stylesheets(site)
    ast = Loader.Stylesheet.build_ast(site, stylesheets)
    stop(compile_module(site, ast), config)
  end

  def handle_call({:reload_layout_module, layout_id}, _from, config) do
    %{site: site} = config
    layout = Beacon.Content.get_published_layout(site, layout_id)

    case layout do
      nil ->
        {:error, :layout_not_published}

      layout ->
        ast = Loader.Layout.build_ast(site, layout)
        result = compile_module(site, ast)
        stop(result, config)
    end
  end

  def handle_call({:reload_page_module, page_id}, _from, config) do
    %{site: site} = config
    page = Beacon.Content.get_published_page(site, page_id)

    case page do
      nil ->
        stop({:error, :page_not_published}, config)

      page ->
        ast = Loader.Page.build_ast(site, page)
        result = compile_module(site, ast)
        :ok = Beacon.PubSub.page_loaded(page)
        stop(result, config)
    end
  end

  def handle_call(:reload_runtime_js, _from, config) do
    stop(Beacon.RuntimeJS.load!(), config)
  end

  def handle_call(:reload_runtime_css, _from, config) do
    stop(Beacon.RuntimeCSS.load!(config.site), config)
  end

  def handle_call({:unload_page_module, page_id}, _from, config) do
    %{site: site} = config

    case Beacon.Content.get_published_page(site, page_id) do
      nil ->
        stop({:error, :page_not_published}, config)

      page ->
        page.site
        |> Loader.Page.module_name(page.id)
        |> Compiler.unload()

        stop(:ok, config)
    end
  end

  def handle_info(msg, config) do
    Logger.warning("Beacon.Loader.Worker can not handle the message: #{inspect(msg)}")
    {:noreply, config}
  end

  defp stop(reply, state) do
    {:stop, :shutdown, reply, state}
  end

  defp compile_module(site, ast) do
    case Compiler.compile_module(site, ast) do
      {:ok, module, []} ->
        module

      {:ok, module, diagnostics} ->
        Logger.warning("""
        compiling module #{module} returned diagnostics

          #{inspect(diagnostics)}

        """)

      {:error, module, {error, diagnostics}} ->
        raise """
        failed to compile module #{module}

          Got:

            Error: #{inspect(error)}

            Diagnostics: #{inspect(diagnostics)}

        """

      {:error, error} ->
        raise """
        failed to compile module

          Got: #{inspect(error)}

        """
    end
  end
end
