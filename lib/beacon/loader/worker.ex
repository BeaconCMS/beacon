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
    # they are compiled and loaded individually
    u = System.unique_integer([:positive])
    Beacon.Registry.via({site, __MODULE__, u})
  end

  def init(config) do
    Beacon.ErrorHandler.enable(config.site)
    {:ok, config}
  end

  def handle_call(:ping, _from, config) do
    stop(:pong, config)
  end

  def handle_call({:apply_mfa, module, function, args}, _from, config) do
    result = apply(module, function, args)
    {:stop, :shutdown, {:ok, result}, config}
  rescue
    error ->
      {:stop, :shutdown, {:error, error, __STACKTRACE__}, config}
  end

  def handle_call(:populate_default_media, _from, config) do
    %{site: site} = config
    path = Path.join(Application.app_dir(:beacon, "priv"), "beacon.png")

    case Beacon.MediaLibrary.search(site, "beacon.webp") do
      [] ->
        Beacon.MediaLibrary.UploadMetadata.new(
          site,
          path,
          name: "beacon.png",
          extra: %{"alt" => "logo"}
        )
        |> Beacon.MediaLibrary.upload()

      _ ->
        :skip
    end

    stop(:ok, config)
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
          %{
            site: site,
            layout_id: default_layout.id,
            path: "/",
            title: "My Home Page",
            template: ~S"""
            <div class="bg-white min-h-screen bg-gradient-to-br from-gray-50 via-white to-gray-50 flex flex-col">
              <div class="text-gray-900 flex-1 flex items-center justify-center">
                <div class="max-w-screen-lg w-full px-4 sm:px-6 lg:px-8 py-8 sm:py-12">
                  <div class="text-center">
                    <h1 class="font-bold text-5xl sm:text-6xl lg:text-7xl mb-4 bg-clip-text text-transparent bg-gradient-to-r from-gray-900 to-gray-700">Beacon</h1>
                    <p class="mb-8 sm:mb-12 text-2xl sm:text-3xl font-light text-gray-600">
                      Performance without compromising productivity
                    </p>
                    <div class="flex flex-wrap justify-center gap-4 mb-12">
                      <a
                        href="https://hexdocs.pm/beacon"
                        class="inline-flex items-center gap-2 px-6 py-3 bg-gray-900 text-white rounded-lg hover:bg-gray-800 transition-colors duration-200"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M12 6.042A8.967 8.967 0 0 0 6 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 0 1 6 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 0 1 6-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0 0 18 18a8.967 8.967 0 0 0-6 2.292m0-14.25v14.25" />
                        </svg>
                        Beacon Docs
                      </a>
                      <a
                        href="https://hexdocs.pm/beacon_live_admin"
                        class="inline-flex items-center gap-2 px-6 py-3 bg-gray-900 text-white rounded-lg hover:bg-gray-800 transition-colors duration-200"
                      >
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M12 6.042A8.967 8.967 0 0 0 6 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 0 1 6 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 0 1 6-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0 0 18 18a8.967 8.967 0 0 0-6 2.292m0-14.25v14.25" />
                        </svg>
                        LiveAdmin Docs
                      </a>
                    </div>
                  </div>

                  <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 text-sm">
                    <div class="p-4 sm:p-6 bg-white text-gray-900 border border-gray-200 rounded-xl hover:border-gray-300 hover:shadow-lg transition-all duration-300">
                      <h2 class="pb-2 text-base font-bold text-gray-900">SEO-friendly</h2>
                      <p class="text-gray-600">
                        Out-of-the-box fast page rendering and high scores, even with dynamic data.
                      </p>
                    </div>
                    <div class="p-4 sm:p-6 bg-white text-gray-900 border border-gray-200 rounded-xl hover:border-gray-300 hover:shadow-lg transition-all duration-300">
                      <h2 class="pb-2 text-base font-bold text-gray-900">Practical</h2>
                      <p class="text-gray-600">Updating your site is a click away, without slow deployments.</p>
                    </div>
                    <div class="p-4 sm:p-6 bg-white text-gray-900 border border-gray-200 rounded-xl hover:border-gray-300 hover:shadow-lg transition-all duration-300">
                      <h2 class="pb-2 text-base font-bold text-gray-900">Scalable</h2>
                      <p class="text-gray-600">
                        Start serving thousands of requests and upgrade to a cluster to go far beyond.
                      </p>
                    </div>
                    <div class="p-4 sm:p-6 bg-white text-gray-900 border border-gray-200 rounded-xl hover:border-gray-300 hover:shadow-lg transition-all duration-300">
                      <h2 class="pb-2 text-base font-bold text-gray-900">Open-Source</h2>
                      <p class="text-gray-600">
                        Verify, contribute, and adapt to your needs. A project for the community.
                      </p>
                    </div>
                  </div>

                  <div class="mt-12 sm:mt-16 leading-relaxed">
                    <h2 class="text-3xl sm:text-4xl font-bold mb-4 text-gray-900">Features</h2>
                    <p class="mb-6 sm:mb-8 text-gray-600">
                      Check out the
                      <a
                        href="https://github.com/BeaconCMS/beacon_demo"
                        class="text-gray-900 hover:text-gray-700 transition-colors duration-300 border-b border-gray-300 hover:border-gray-600"
                      >
                        demo application
                      </a>
                      to learn about the features listed below. Run it, change it, and deploy your site.
                    </p>

                    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 sm:gap-8">
                      <div class="py-3 sm:py-4 pr-4">
                        <h2 class="mb-2 font-bold text-xl sm:text-2xl text-gray-900">Visual Page Builder</h2>
                        <p class="text-gray-600">
                          Drag and drop HTML elements and Components into your page template, and change attributes and classes. Works with HTML and HEEx templates.
                        </p>
                      </div>

                      <div class="py-3 sm:py-4 pr-4">
                        <h2 class="mb-2 font-bold text-xl sm:text-2xl text-gray-900">Components</h2>
                        <p class="text-gray-600">
                          Reuse Phoenix Components to speed up the development of pages. Common components are already integrated and you can create more.
                        </p>
                      </div>

                      <div class="py-3 sm:py-4 pr-4">
                        <h2 class="mb-2 font-bold text-xl sm:text-2xl text-gray-900">Media Library</h2>
                        <p class="text-gray-600">
                          Upload images, videos, documents, and virtually any kind of media. Process the files, store them in a cloud provider, and render them in your pages.
                        </p>
                      </div>

                      <div class="py-3 sm:py-4 pr-4">
                        <h2 class="mb-2 font-bold text-xl sm:text-2xl text-gray-900">Live Data</h2>
                        <p class="text-gray-600">
                          Execute Elixir code to load data from your app, third-party APIs, or any other source. Updates are made available at runtime without the need for deployments.
                        </p>
                      </div>

                      <div class="py-3 sm:py-4 pr-4">
                        <h2 class="mb-2 font-bold text-xl sm:text-2xl text-gray-900">A/B Variants</h2>
                        <p class="text-gray-600">
                          Create N versions of a page, and tell a story in different perspectives and styles to measure conversion. Each version has a weight to be served more or less.
                        </p>
                      </div>

                      <div class="py-3 sm:py-4 pr-4">
                        <h2 class="mb-2 font-bold text-xl sm:text-2xl text-gray-900">Error Pages</h2>
                        <p class="text-gray-600">
                          Sometimes error happens but you can create personalized and informative error pages to guide your visitors back to finding the right page and increase engagement.
                        </p>
                      </div>

                      <div class="py-3 sm:py-4 pr-4">
                        <h2 class="mb-2 font-bold text-xl sm:text-2xl text-gray-900">Built-in TailwindCSS</h2>
                        <p class="text-gray-600">
                          Start prototyping your site right away with tailwind utility classes on the code editor or the visual page builder. The compiler generates compact assets to keep your site fast.
                        </p>
                      </div>

                      <div class="py-3 sm:py-4 pr-4">
                        <h2 class="mb-2 font-bold text-xl sm:text-2xl text-gray-900">And more...</h2>
                        <p class="text-gray-600">
                          Much more is available: meta tags, Schema.org support, authorization, authentication, custom page fields, custom admin pages, and more. Beacon is constantly evolving.
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <footer class="text-center py-4 sm:py-6 w-full flex flex-col items-center text-sm font-bold text-gray-600 tracking-wide border-t border-gray-200">
                <div class="flex flex-col sm:flex-row justify-center items-center gap-2 sm:gap-4">
                  <a
                    href="https://beaconcms.org"
                    class="inline-flex items-center gap-2 p-2 sm:p-3 no-underline hover:text-gray-900 hover:underline hover:decoration-dashed underline-offset-4"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 0 0 8.716-6.747M12 21a9.004 9.004 0 0 1-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 0 1 7.843 4.582M12 3a8.997 8.997 0 0 0-7.843 4.582m15.686 0A11.953 11.953 0 0 1 12 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0 1 21 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0 1 12 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 0 1 3 12c0-1.605.42-3.113 1.157-4.418" />
                    </svg>
                    BeaconCMS.org
                  </a>
                  <a
                    href="https://github.com/BeaconCMS/beacon"
                    class="inline-flex items-center gap-2 p-2 sm:p-3 no-underline hover:text-gray-900 hover:underline hover:decoration-dashed underline-offset-4"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M17.25 6.75 22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3-4.5 16.5" />
                    </svg>
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

  # todo: remove
  def handle_call(request, _from, config)
      when request in [
             :load_snippets_module,
             :load_routes_module,
             :load_components_module,
             :load_live_data_module,
             :load_error_page_module,
             :load_stylesheet_module,
             :load_event_handlers_module,
             :load_info_handlers_module
           ] do
    __MODULE__
    |> apply(request, [config.site])
    |> stop(config)
  end

  def handle_call({:load_layout_module, layout_id}, _from, config) do
    config.site
    |> load_layout_module(layout_id)
    |> stop(config)
  end

  def handle_call({:load_page_module, page_id}, _from, config) do
    config.site
    |> load_page_module(page_id)
    |> stop(config)
  end

  def handle_call(:load_runtime_js, _from, config) do
    stop(Beacon.RuntimeJS.load!(config.site), config)
  end

  def handle_call(:load_runtime_css, _from, config) do
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
        |> Loader.unload()

        stop(:ok, config)
    end
  end

  def handle_info(msg, config) do
    Logger.warning("Beacon.Loader.Worker can not handle the message: #{inspect(msg)}")
    {:noreply, config}
  end

  def load_snippets_module(site) do
    module = Loader.fetch_snippets_module(site)

    safe_load(module, fn ->
      snippets = Content.list_snippet_helpers(site)
      ast = Loader.Snippets.build_ast(site, snippets)
      {:ok, ^module} = compile_module(ast, "snippets")
    end)
  end

  def load_routes_module(site) do
    module = Loader.fetch_routes_module(site)

    safe_load(module, fn ->
      ast = Loader.Routes.build_ast(site)
      {:ok, ^module} = compile_module(ast, "routes")
    end)
  end

  def load_components_module(site) do
    module = Loader.fetch_components_module(site)

    safe_load(module, fn ->
      components = Content.list_components(site, per_page: :infinity, preloads: [:attrs, slots: [:attrs]])
      ast = Loader.Components.build_ast(site, components)
      {:ok, ^module} = compile_module(ast, "components")
    end)
  end

  def load_live_data_module(site) do
    module = Loader.fetch_live_data_module(site)

    safe_load(module, fn ->
      live_data = Content.live_data_for_site(site)
      ast = Loader.LiveData.build_ast(site, live_data)
      {:ok, ^module} = compile_module(ast, "live_data")
    end)
  end

  def load_error_page_module(site) do
    module = Loader.fetch_error_page_module(site)

    safe_load(module, fn ->
      error_pages = Content.list_error_pages(site, preloads: [:layout])
      ast = Loader.ErrorPage.build_ast(site, error_pages)
      {:ok, ^module} = compile_module(ast, "error_pages")
    end)
  end

  def load_stylesheet_module(site) do
    module = Loader.fetch_stylesheet_module(site)

    safe_load(module, fn ->
      stylesheets = Content.list_stylesheets(site)
      ast = Loader.Stylesheet.build_ast(site, stylesheets)
      {:ok, ^module} = compile_module(ast, "stylesheets")
    end)
  end

  def load_event_handlers_module(site) do
    module = Loader.fetch_event_handlers_module(site)

    safe_load(module, fn ->
      event_handlers = Content.list_event_handlers(site)
      ast = Loader.EventHandlers.build_ast(site, event_handlers)
      {:ok, ^module} = compile_module(ast, "event_handlers")
    end)
  end

  def load_info_handlers_module(site) do
    module = Loader.fetch_info_handlers_module(site)

    safe_load(module, fn ->
      info_handlers = Content.list_info_handlers(site)
      ast = Loader.InfoHandlers.build_ast(site, info_handlers)
      {:ok, ^module} = compile_module(ast, "info_handlers")
    end)
  end

  def load_layout_module(site, layout_id) do
    layout = Beacon.Content.get_published_layout(site, layout_id)
    module = Loader.fetch_layout_module(site, layout_id)

    case layout do
      nil ->
        {:error, :layout_not_published}

      layout ->
        safe_load(module, fn ->
          ast = Loader.Layout.build_ast(site, layout)
          {:ok, ^module} = compile_module(ast, "layout")
        end)
    end
  end

  def load_page_module(site, page_id) do
    page = Beacon.Content.get_published_page(site, page_id)
    module = Loader.fetch_page_module(site, page_id)

    case page do
      nil ->
        {:error, :page_not_published}

      page ->
        safe_load(module, fn ->
          ast = Beacon.Loader.Page.build_ast(site, page)
          {:ok, ^module} = compile_module(ast, "page")
          :ok = Beacon.PubSub.page_loaded(page)
        end)
    end
  end

  def load_runtime_js(site) do
    Beacon.RuntimeJS.load!(site)
  end

  defp stop(reply, state) do
    {:stop, {:shutdown, :loaded}, reply, state}
  end

  defp compile_module(ast, file) do
    case Compiler.compile_module(ast, file) do
      {:ok, module, []} ->
        {:ok, module}

      {:ok, module, diagnostics} ->
        Logger.warning("""
        compiling module #{module} returned diagnostics

          #{inspect(diagnostics)}

        """)

        {:ok, module}

      {:error, module, {error, diagnostics}} = result ->
        Logger.error("""
        failed to compile module #{module}

          Error: #{inspect(error)}

          Diagnostics: #{inspect(diagnostics)}

        """)

        result

      {:error, error} = result ->
        Logger.error("""
        failed to compile module

          Error: #{inspect(error)}

        """)

        result
    end
  end

  # this is a global lock to ensure that `load_fn` only runs for one worker per module;
  # duplicate workers will simply wait for the first one
  defp safe_load(module, load_fn) do
    case Registry.register(Beacon.Registry, module, module) do
      {:ok, _pid} ->
        # we are the first worker, let's do the work
        load_fn.()
        Registry.unregister(Beacon.Registry, module)
        module

      {:error, {:already_registered, pid}} ->
        # another worker already started, let's wait for it
        _ref = Process.monitor(pid)
        time_to_wait = if(Beacon.Config.env_test?(), do: 500, else: 15_000)

        receive do
          {:DOWN, _ref, :process, _pid, {:shutdown, :loaded}} -> module
        after
          time_to_wait -> :error
        end
    end
  end
end
