defmodule Beacon.Loader do
  @moduledoc """
  Resources loading
  """

  use GenServer
  require Logger
  alias Beacon.Content
  alias Beacon.PubSub

  @doc false
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  @doc false
  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  @doc false
  def init(config) do
    if Code.ensure_loaded?(Mix.Project) and Mix.env() == :test do
      :skip
    else
      Logger.debug("#### About to populate components")
      with :ok <- populate_components(config.site) do
        Logger.debug("#### About to load the site from DB")
        :ok = load_site_from_db(config.site)
      end
    end

    PubSub.subscribe_to_layouts(config.site)
    PubSub.subscribe_to_pages(config.site)

    {:ok, config}
  end

  defp populate_components(site) do
    nav_1 = """
      <nav>
        <div class="flex justify-between px-8 py-5 bg-white">
          <div class="w-auto mr-14">
            <a href="#"><img src="https://shuffle.dev/gradia-assets/logos/gradia-name-black.svg"></a>
          </div>
          <div class="w-auto flex flex-wrap items-center">
            <ul class="flex items-center mr-10">
              <li class="mr-9 text-gray-900 hover:text-gray-700 text-lg">
                <a href="#">Features</a>
              </li>
              <li class="mr-9 text-gray-900 hover:text-gray-700 text-lg">
                <a href="#">Solutions</a>
              </li>
              <li class="mr-9 text-gray-900 hover:text-gray-700 text-lg">
                <a href="#">Resources</a>
              </li>
              <li class="mr-9 text-gray-900 hover:text-gray-700 text-lg">
                <a href="#">Pricing</a>
              </li>
            </ul>
            <button class="text-white px-2 py-1 block w-full md:w-auto text-lg text-gray-900 font-medium overflow-hidden rounded-10 bg-blue-500 rounded">
              Start Free Trial
            </button>
          </div>
        </div>
      </nav>
    """
    nav_2 = """
      <nav>
        <div class="flex justify-between px-8 py-5 bg-white">
          <div class="w-auto mr-14">
            <a href="#">
              <img src="https://shuffle.dev/gradia-assets/logos/gradia-name-black.svg">
            </a>
          </div>
          <div class="w-auto flex flex-wrap items-center">
            <ul class="flex items-center mr-10">
              <li class="mr-9 text-gray-900 hover:text-gray-700 text-lg">
                <a href="#">Features</a>
              </li>
              <li class="mr-9 text-gray-900 hover:text-gray-700 text-lg">
                <a href="#">Solutions</a>
              </li>
              <li class="mr-9 text-gray-900 hover:text-gray-700 text-lg">
                <a href="#">Resources</a>
              </li>
              <li class="mr-9 text-gray-900 hover:text-gray-700 text-lg">
                <a href="#">Pricing</a>
              </li>
            </ul>
          </div>
          <div class="w-auto flex flex-wrap items-center">
            <button class="text-white px-2 py-1 block w-full md:w-auto text-lg text-gray-900 font-medium overflow-hidden rounded-10 bg-blue-500 rounded">
              Start Free Trial
            </button>
          </div>
        </div>
      </nav>
    """
    header_1 = """
      <div class="container mx-auto px-4">
      <div class="max-w-xl">
      <span class="inline-block mb-3 text-gray-600 text-base">
      Flexible Pricing Plan
    </span>
    <h2 class="mb-16 font-heading font-bold text-6xl sm:text-7xl text-gray-900">
      Everything you need to launch a website
    </h2>

    </div>
    <div class="flex flex-wrap">
      <div class="w-full md:w-1/3">
      <div class="pt-8 px-11 xl:px-20 pb-10 bg-transparent border-b md:border-b-0 md:border-r border-gray-200 rounded-10">
      <h3 class="mb-0.5 font-heading font-semibold text-lg text-gray-900">
      Basic
    </h3>
    <p class="mb-5 text-gray-600 text-sm">
      Best for freelancers
    </p>
    <div class="mb-9 flex">
      <span class="mr-1 mt-0.5 font-heading font-semibold text-lg text-gray-900">$</span>
    <span class="font-heading font-semibold text-6xl sm:text-7xl text-gray-900">29</span>
    <span class="font-heading font-semibold self-end">/ m</span>

    </div>
    <div class="p-1">
      <button class="group relative mb-9 p-px w-full font-heading font-semibold text-xs text-gray-900 bg-gradient-green uppercase tracking-px overflow-hidden rounded-md">
      <div class="absolute top-0 left-0 transform -translate-y-full group-hover:-translate-y-0 h-full w-full bg-gradient-green transition ease-in-out duration-500">

    </div>
    <div class="p-4 bg-gray-50 overflow-hidden rounded-md">
      <p class="relative z-10">
      Join now
    </p>
    </div>
    </button>
    </div>
    <ul>
      <li class="flex items-center font-heading mb-3 font-medium text-base text-gray-900">
      <svg class="mr-2.5">
      <path d="M4.58301 11.9167L8.24967 15.5834L17.4163 6.41669" stroke="#A1A1AA" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" data-path="0.0.1.0.0.4.0.0.0"></path>
    </svg>
    <p>
      100GB Cloud Storage
    </p>

    </li>
    <li class="flex items-center font-heading mb-3 font-medium text-base text-gray-900">
      <svg class="mr-2.5">
      <path d="M4.58301 11.9167L8.24967 15.5834L17.4163 6.41669" stroke="#A1A1AA" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" data-path="0.0.1.0.0.4.1.0.0"></path>
    </svg>
    <p>
      10 Email Connection
    </p>

    </li>
    <li class="flex items-center font-heading font-medium text-base text-gray-900">
      <svg class="mr-2.5">
      <path d="M4.58301 11.9167L8.24967 15.5834L17.4163 6.41669" stroke="#A1A1AA" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" data-path="0.0.1.0.0.4.2.0.0"></path>
    </svg>
    <p>
      Daily Analytics
    </p>
    </li>
    </ul>
    </div>

    </div>
    <div class="w-full md:w-1/3">
      <div class="pt-8 px-11 xl:px-20 pb-10 bg-transparent rounded-10">
      <h3 class="mb-0.5 font-heading font-semibold text-lg text-gray-900">
      Premium
    </h3>
    <p class="mb-5 text-gray-600 text-sm">
      Best for small agency
    </p>
    <div class="mb-9 flex">
      <span class="mr-1 mt-0.5 font-heading font-semibold text-lg text-gray-900">
      $
    </span>
    <span class="font-heading font-semibold text-6xl sm:text-7xl text-gray-900">
      99
    </span>
    <span class="font-heading font-semibold self-end">
      / m
    </span>
    </div>
    <div class="p-1">
      <button class="group relative mb-9 p-px w-full font-heading font-semibold text-xs text-gray-900 bg-gradient-green uppercase tracking-px overflow-hidden rounded-md">
      <div class="absolute top-0 left-0 transform -translate-y-full group-hover:-translate-y-0 h-full w-full bg-gradient-green transition ease-in-out duration-500">

    </div>
    <div class="p-4 bg-gray-50 overflow-hidden rounded-md">
      <p class="relative z-10">Join now</p>

    </div>
    </button>
    </div>
    <ul>
      <li class="flex items-center font-heading mb-3 font-medium text-base text-gray-900">
      <svg class="mr-2.5">
      <path d="M4.58301 11.9167L8.24967 15.5834L17.4163 6.41669" stroke="#A1A1AA" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" data-path="0.0.1.1.0.4.0.0.0"></path>
    </svg>
    <p>
      500GB Cloud Storage
    </p>

    </li>
    <li class="flex items-center font-heading mb-3 font-medium text-base text-gray-900">
      <svg class="mr-2.5">
      <path d="M4.58301 11.9167L8.24967 15.5834L17.4163 6.41669" stroke="#A1A1AA" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" data-path="0.0.1.1.0.4.1.0.0"></path>
    </svg>
    <p>
      50 Email Connection
    </p>

    </li>
    <li class="flex items-center font-heading mb-3 font-medium text-base text-gray-900">
      <svg class="mr-2.5">
      <path d="M4.58301 11.9167L8.24967 15.5834L17.4163 6.41669" stroke="#A1A1AA" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" data-path="0.0.1.1.0.4.2.0.0"></path>
    </svg>
    <p>
      Daily Analytics
    </p>
    </li>
    <li class="flex items-center font-heading font-medium text-base text-gray-900">
      <svg class="mr-2.5">
      <path d="M4.58301 11.9167L8.24967 15.5834L17.4163 6.41669" stroke="#A1A1AA" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" data-path="0.0.1.1.0.4.3.0.0"></path>
    </svg>
    <p>
      Premium Support
    </p>
    </li>
    </ul>
    </div>
    </div>
    <div class="w-full md:w-1/3">
      <div class="relative pt-8 px-11 pb-10 bg-white rounded-10 shadow-8xl">
      <p class="absolute right-2 top-2 font-heading px-2.5 py-1 text-xs max-w-max bg-gray-100 uppercase tracking-px rounded-full text-gray-900">
      Popular choice
    </p>
    <h3 class="mb-0.5 font-heading font-semibold text-lg text-gray-900">
      Enterprise
    </h3>
    <p class="mb-5 text-gray-600 text-sm">
      Best for large agency
    </p>
    <div class="mb-9 flex">
      <span class="mr-1 mt-0.5 font-heading font-semibold text-lg text-gray-900">
      $
    </span>
    <span class="font-heading font-semibold text-6xl sm:text-7xl text-gray-900">
      199
    </span>
    <span class="font-heading font-semibold self-end">
      / m
    </span>

    </div>
    <div class="group relative mb-9">
      <div class="absolute top-0 left-0 w-full h-full bg-gradient-green opacity-0 group-hover:opacity-50 p-1 rounded-lg transition ease-out duration-300">

    </div>
    <button class="p-1 w-full font-heading font-semibold text-xs text-gray-900 uppercase tracking-px overflow-hidden rounded-md">
      <div class="relative z-10 p-4 bg-gradient-green overflow-hidden rounded-md">
      <p>
      Join now
    </p>

    </div>

    </button>

    </div>
    <ul>
      <li class="flex items-center font-heading mb-3 font-medium text-base text-gray-900">
      <svg class="mr-2.5">
      <path d="M4.58301 11.9167L8.24967 15.5834L17.4163 6.41669" stroke="#A1A1AA" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" data-path="0.0.1.2.0.5.0.0.0"></path>
    </svg>
    <p>
      2TB Cloud Storage
    </p>

    </li>
    <li class="flex items-center font-heading mb-3 font-medium text-base text-gray-900">
      <svg class="mr-2.5">
      <path d="M4.58301 11.9167L8.24967 15.5834L17.4163 6.41669" stroke="#A1A1AA" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" data-path="0.0.1.2.0.5.1.0.0"></path>
    </svg>
    <p>
      Unlimited Email Connection
    </p>

    </li>
    <li class="flex items-center font-heading mb-3 font-medium text-base text-gray-900">
      <svg class="mr-2.5">
      <path d="M4.58301 11.9167L8.24967 15.5834L17.4163 6.41669" stroke="#A1A1AA" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" data-path="0.0.1.2.0.5.2.0.0"></path>
    </svg>
    <p>
      Daily Analytics
    </p>

    </li>
    <li class="flex items-center font-heading font-medium text-base text-gray-900">
      <svg class="mr-2.5">
      <path d="M4.58301 11.9167L8.24967 15.5834L17.4163 6.41669" stroke="#A1A1AA" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" data-path="0.0.1.2.0.5.3.0.0"></path>
    </svg>
    <p>
      Premium Support
    </p>
    </li>
    </ul>
    </div>
    </div>
    </div>
    </div>
    """
    component_attrs = [
      %{
        name: "Navigation 1",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/navigations/01_2be7c9d07f.png",
        body: nav_1,
        category: :nav
      },
      %{
        name: "Navigation 2",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/navigations/02_0f54c9f964.png",
        body: nav_2,
        category: :nav
      },
      %{
        name: "Navigation 3",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/navigations/03_e244675766.png",
        body: nav_1,
        category: :nav
      },
      %{
        name: "Navigation 4",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/navigations/04_64390b9975.png",
        body: nav_1,
        category: :nav
      },
      %{
        name: "Header 1",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/headers/01_b9f658e4b8.png",
        body: header_1,
        category: :header
      },
      %{
        name: "Header 2",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/headers/01_b9f658e4b8.png",
        body: "<div>Default definition for components</div>",
        category: :header
      },
      %{
        name: "Header 3",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/headers/01_b9f658e4b8.png",
        body: "<div>Default definition for components</div>",
        category: :header
      },
      %{
        name: "Sign Up 1",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-up/01_c10e6e5d95.png",
        body: "<div>Default definition for components</div>",
        category: :sign_up
      },
      %{
        name: "Sign Up 2",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-up/01_c10e6e5d95.png",
        body: "<div>Default definition for components</div>",
        category: :sign_up
      },
      %{
        name: "Sign Up 3",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-up/01_c10e6e5d95.png",
        body: "<div>Default definition for components</div>",
        category: :sign_up
      },
      %{
        name: "Stats 1",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/numbers/01_204956d540.png",
        body: "<div>Default definition for components</div>",
        category: :stats
      },
      %{
        name: "Stats 2",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/numbers/01_204956d540.png",
        body: "<div>Default definition for components</div>",
        category: :stats
      },
      %{
        name: "Stats 3",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/numbers/01_204956d540.png",
        body: "<div>Default definition for components</div>",
        category: :stats
      },
      %{
        name: "Footer 1",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png",
        body: "<div>Default definition for components</div>",
        category: :footer
      },
      %{
        name: "Footer 2",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png",
        body: "<div>Default definition for components</div>",
        category: :footer
      },
      %{
        name: "Footer 3",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/footers/01_1648bd354f.png",
        body: "<div>Default definition for components</div>",
        category: :footer
      },
      %{
        name: "Sign In 1",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-in/01_b25eff87e3.png",
        body: "<div>Default definition for components</div>",
        category: :sign_in
      },
      %{
        name: "Sign In 2",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-in/01_b25eff87e3.png",
        body: "<div>Default definition for components</div>",
        category: :sign_in
      },
      %{
        name: "Sign In 3",
        thumbnail: "https://static.shuffle.dev/components/preview/43b384c1-17c4-470b-8332-d9dbb5ee99d7/sign-in/01_b25eff87e3.png",
        body: "<div>Default definition for components</div>",
        category: :sign_in
      },
      %{
        name: "Title",
        thumbnail: "/component_thumbnails/title.jpg",
        body: "<header>I'm a sample title</header>",
        category: :basic
      },
      %{
        name: "Button",
        thumbnail: "/component_thumbnails/button.jpg",
        body: "<button>I'm a sample button</button>",
        category: :basic
      },
      %{
        name: "Link",
        thumbnail: "/component_thumbnails/link.jpg",
        body: "<a href=\"#\">I'm a sample link</a>",
        category: :basic
      },
      %{
        name: "Paragraph",
        thumbnail: "/component_thumbnails/paragraph.jpg",
        body: "<p>I'm a sample paragraph</p>",
        category: :basic
      },
      %{
        name: "Aside",
        thumbnail: "/component_thumbnails/aside.jpg",
        body: "<aside>I'm a sample aside</aside>",
        category: :basic
      }
    ]
    Logger.debug("### About to create the components for #{site}")
    Logger.debug(component_attrs)
    components =
      component_attrs
      |> Enum.map(fn attrs -> Content.create_component!(Map.put(attrs, :site, site)) end)
    Logger.debug("### Components have been created ->")
    Logger.debug(components)
    :ok
  end

  defp load_site_from_db(site) do
    with :ok <- Beacon.RuntimeJS.load(),
         :ok <- load_runtime_css(site),
         :ok <- load_stylesheets(site),
         :ok <- load_components(site),
         :ok <- load_snippet_helpers(site),
         :ok <- load_layouts(site),
         :ok <- load_pages(site) do
      :ok
    else
      _ -> raise Beacon.LoaderError, message: "failed to load resources for site #{site}"
    end
  end

  @doc """
  Reload all resources of `site`.

  Note that it may leave the site unresponsive
  until it finishes loading all resources.
  """
  @spec reload_site(Beacon.Types.Site.t()) :: :ok
  def reload_site(site) when is_atom(site) do
    config = Beacon.Config.fetch!(site)
    GenServer.call(name(config.site), {:reload_site, config.site}, 300_000)
  end

  @doc false
  def load_page(%Content.Page{} = page) do
    config = Beacon.Config.fetch!(page.site)
    GenServer.call(name(config.site), {:load_page, page}, 60_000)
  end

  @doc false
  def reload_module!(module, ast, file \\ "nofile") do
    :code.delete(module)
    :code.purge(module)
    [{^module, _}] = Code.compile_quoted(ast, file)
    {:module, ^module} = Code.ensure_loaded(module)
    :ok
  rescue
    e ->
      message = """
      failed to load module #{inspect(module)}

      Got:

        #{Exception.message(e)}"],

      """

      reraise Beacon.LoaderError, [message: message], __STACKTRACE__
  end

  defp load_runtime_css(site) do
    # too slow to run the css compiler on every test
    if Code.ensure_loaded?(Mix.Project) and Mix.env() == :test do
      :ok
    else
      Beacon.RuntimeCSS.load(site)
    end
  end

  defp load_stylesheets(site) do
    Beacon.Loader.StylesheetModuleLoader.load_stylesheets(
      site,
      Beacon.Content.list_stylesheets(site)
    )

    :ok
  end

  # TODO: replace my_component in favor of https://github.com/BeaconCMS/beacon/issues/84
  defp load_components(site) do
    components = Beacon.Content.list_components(site)
    Logger.debug("##### Loaded components!!")
    Logger.debug(components)
    Beacon.Loader.ComponentModuleLoader.load_components(
      site,
      components
    )

    :ok
  end

  @doc false
  def load_snippet_helpers(site) do
    Beacon.Loader.SnippetModuleLoader.load_helpers(
      site,
      Beacon.Content.list_snippet_helpers(site)
    )

    :ok
  end

  defp load_layouts(site) do
    site
    |> Content.list_published_layouts()
    |> Enum.map(fn layout ->
      Task.async(fn ->
        {:ok, _ast} = Beacon.Loader.LayoutModuleLoader.load_layout!(layout)
        :ok
      end)
    end)
    |> Task.await_many(60_000)

    :ok
  end

  defp load_pages(site) do
    site
    |> Content.list_published_pages()
    |> Enum.map(fn page ->
      Task.async(fn ->
        {:ok, _ast} = Beacon.Loader.PageModuleLoader.load_page!(page)
        :ok
      end)
    end)
    |> Task.await_many(300_000)

    :ok
  end

  @doc false
  def stylesheet_module_for_site(site) do
    module_for_site(site, "Stylesheet")
  end

  @doc false
  def component_module_for_site(site) do
    module_for_site(site, "Component")
  end

  @doc false
  def snippet_helpers_module_for_site(site) do
    module_for_site(site, "SnippetHelpers")
  end

  @doc false
  def layout_module_for_site(site, layout_id) do
    prefix = Macro.camelize("layout_#{layout_id}")
    module_for_site(site, prefix)
  end

  @doc false
  def page_module_for_site(site, page_id) do
    prefix = Macro.camelize("page_#{page_id}")
    module_for_site(site, prefix)
  end

  defp module_for_site(site, prefix) do
    site_hash = :crypto.hash(:md5, Atom.to_string(site)) |> Base.encode16()
    Module.concat([BeaconWeb.LiveRenderer, "#{prefix}#{site_hash}"])
  end

  # This retry logic exists because a module may be in the process of being reloaded, in which case we want to retry
  @doc false
  def call_function_with_retry(module, function, args, failure_count \\ 0) do
    apply(module, function, args)
  rescue
    e in UndefinedFunctionError ->
      case {failure_count, e} do
        {x, _} when x >= 10 ->
          Logger.debug("failed to call #{inspect(module)} #{inspect(function)} 10 times.")
          reraise e, __STACKTRACE__

        {_, %UndefinedFunctionError{function: ^function, module: ^module}} ->
          Logger.debug("failed to call #{inspect(module)} #{inspect(function)} with #{inspect(args)} for the #{failure_count + 1} time. Retrying.")

          :timer.sleep(100 * (failure_count * 2))

          call_function_with_retry(module, function, args, failure_count + 1)

        _ ->
          reraise e, __STACKTRACE__
      end

    _e in FunctionClauseError ->
      error_message = """
      Could not call #{function} for the given path: #{inspect(List.flatten(args))}.

      Make sure you have created a page for this path. Check Pages.create_page!/2 \
      for more info.\
      """

      reraise Beacon.LoaderError, [message: error_message], __STACKTRACE__

    e ->
      reraise e, __STACKTRACE__
  end

  @doc false
  def maybe_import_my_component(_component_module, [] = _functions) do
  end

  @doc false
  def maybe_import_my_component(component_module, functions) do
    # TODO: early return
    {_new_ast, present} =
      Macro.prewalk(functions, false, fn
        {:my_component, _, _} = node, _acc -> {node, true}
        node, true -> {node, true}
        node, false -> {node, false}
      end)

    if present do
      quote do
        import unquote(component_module), only: [my_component: 2]
      end
    end
  end

  ## Callbacks

  @doc false
  def handle_call({:reload_site, site}, _from, config) do
    {:reply, load_site_from_db(site), config}
  end

  @doc false
  def handle_call({:load_page, page}, _from, config) do
    :ok = load_runtime_css(page.site)
    {:reply, do_load_page(page), config}
  end

  @doc false
  def handle_info({:layout_published, %{site: site, id: id}}, state) do
    layout = Content.get_published_layout(site, id)

    with :ok <- load_runtime_css(site),
         # TODO: load only used components, depends on https://github.com/BeaconCMS/beacon/issues/84
         :ok <- load_components(site),
         # TODO: load only used snippet helpers
         :ok <- load_snippet_helpers(site),
         :ok <- load_stylesheets(site),
         {:ok, _ast} <- Beacon.Loader.LayoutModuleLoader.load_layout!(layout) do
      :ok
    else
      _ -> raise Beacon.LoaderError, message: "failed to load resources for layout #{layout.title} of site #{layout.site}"
    end

    {:noreply, state}
  end

  @doc false
  def handle_info({:page_published, %{site: site, id: id}}, state) do
    :ok = load_runtime_css(site)

    site
    |> Content.get_published_page(id)
    |> do_load_page()

    {:noreply, state}
  end

  @doc false
  def handle_info({:pages_published, site, pages}, state) do
    :ok = load_runtime_css(site)

    for page <- pages do
      site
      |> Content.get_published_page(page.id)
      |> do_load_page()
    end

    {:noreply, state}
  end

  @doc false
  def handle_info({:page_unpublished, %{site: site, id: id}}, state) do
    site
    |> Content.get_published_page(id)
    |> do_unload_page()

    {:noreply, state}
  end

  @doc false
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def do_load_page(page) when is_nil(page), do: nil

  def do_load_page(page) do
    layout = Content.get_published_layout(page.site, page.layout_id)

    # TODO: load only used components, depends on https://github.com/BeaconCMS/beacon/issues/84
    with :ok <- load_components(page.site),
         # TODO: load only used snippet helpers
         :ok <- load_snippet_helpers(page.site),
         {:ok, _ast} <- Beacon.Loader.LayoutModuleLoader.load_layout!(layout),
         :ok <- load_stylesheets(page.site),
         {:ok, _ast} <- Beacon.Loader.PageModuleLoader.load_page!(page) do
      :ok = Beacon.PubSub.page_loaded(page)
      :ok
    else
      _ -> raise Beacon.LoaderError, message: "failed to load resources for page #{page.title} of site #{page.site}"
    end
  end

  @doc false
  def do_unload_page(page) do
    module = page_module_for_site(page.site, page.id)
    :code.delete(module)
    :code.purge(module)
    Beacon.Router.del_page(page.site, page.path)
    :ok
  end

  @doc false
  # https://github.com/phoenixframework/phoenix_live_view/blob/8fedc6927fd937fe381553715e723754b3596a97/lib/phoenix_live_view/channel.ex#L435-L437
  def exported?(m, f, a) do
    function_exported?(m, f, a) || (Code.ensure_loaded?(m) && function_exported?(m, f, a))
  end
end
