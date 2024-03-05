defmodule Beacon.Loader do
  @moduledoc """
  Loader is the process responsible for loading, unloading, and reloading all resources for each site.

  At start it will load all `Beacon.Content.blueprint_components/0` and existing resources stored
  in the database like layouts, pages, snippets, etc.

  When a resource is changed, for example when a page is published, it will recompile the
  modules and updated the data in ETS to make the updated resource live.

  And deleting a resource will unload it from memory.

  """
  use GenServer

  alias Beacon.Content
  alias Beacon.Loader.ComponentModuleLoader
  alias Beacon.Loader.DataSourceModuleLoader
  alias Beacon.Loader.ErrorPageModuleLoader
  alias Beacon.Loader.LayoutModuleLoader
  alias Beacon.Loader.PageModuleLoader
  alias Beacon.Loader.SnippetModuleLoader
  alias Beacon.Loader.StylesheetModuleLoader
  alias Beacon.PubSub
  alias Beacon.Repo

  require Logger

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
    {:ok, config, {:continue, :load_site_from_db}}
  end

  if Code.ensure_loaded?(Mix.Project) and Mix.env() == :test do
    @doc false
    def handle_continue(:load_site_from_db, config) do
      # avoid compilation warnings
      populate_default_components(nil)
      subscribe_to_events(config.site)

      {:noreply, config}
    end
  else
    @doc false
    def handle_continue(:load_site_from_db, config) do
      %{site: site} = config

      with :ok <- populate_default_components(site),
           :ok <- populate_default_layouts(site),
           :ok <- populate_default_error_pages(site) do
        :ok = load_site_from_db(site)
        subscribe_to_events(site)
      end

      {:noreply, config}
    end
  end

  defp subscribe_to_events(site) do
    PubSub.subscribe_to_layouts(site)
    PubSub.subscribe_to_pages(site)
    PubSub.subscribe_to_components(site)
    PubSub.subscribe_to_error_pages(site)
    PubSub.subscribe_to_live_data(site)
  end

  defp populate_default_components(nil), do: :skip

  defp populate_default_components(site) do
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

    :ok
  end

  @doc false
  def populate_default_layouts(site) do
    case Content.get_layout_by(site, title: "Default") do
      nil ->
        Content.default_layout()
        |> Map.put(:site, site)
        |> Content.create_layout!()
        |> Content.publish_layout()

      _ ->
        :skip
    end

    :ok
  end

  @doc false
  def populate_default_error_pages(site) do
    default_layout = Content.get_layout_by(site, title: "Default")

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

    :ok
  end

  defp load_site_from_db(site) do
    with :ok <- Beacon.RuntimeJS.load!(),
         :ok <- load_components(site),
         :ok <- load_snippet_helpers(site),
         :ok <- load_data_source(site),
         :ok <- load_layouts(site),
         :ok <- load_pages(site),
         :ok <- load_error_pages(site),
         :ok <- load_stylesheets(site),
         :ok <- async_load_runtime_css(site) do
      :ok
    else
      _ -> raise Beacon.LoaderError, message: "failed to load resources for site #{site}"
    end
  end

  @doc """
  Reload all resources of `site`.

  Note that it may leave the site unresponsive until it finishes loading all resources.
  """
  @spec reload_site(Beacon.Types.Site.t()) :: :ok
  def reload_site(site) when is_atom(site) do
    config = Beacon.Config.fetch!(site)
    GenServer.call(name(config.site), {:reload_site, config.site}, 300_000)
  end

  @doc false
  def load_page(%Content.Page{} = page) do
    page = Repo.preload(page, :event_handlers)
    config = Beacon.Config.fetch!(page.site)
    GenServer.call(name(config.site), {:load_page, page}, 30_000)
  end

  def load_page_template(%Content.Page{} = page, page_module, assigns) when is_atom(page_module) and is_map(assigns) do
    config = Beacon.Config.fetch!(page.site)
    GenServer.call(name(config.site), {:load_page_template, page, page_module, assigns}, 30_000)
  end

  @doc false
  def unload_page(%Content.Page{} = page) do
    config = Beacon.Config.fetch!(page.site)
    GenServer.call(name(config.site), {:unload_page, page}, 30_000)
  end

  @doc false
  def reload_module!(module, ast, file \\ "nofile", failure_count \\ 0) do
    :code.delete(module)
    :code.purge(module)
    [{^module, _}] = Code.compile_quoted(ast, file)
    {:module, ^module} = Code.ensure_loaded(module)
    :ok
  rescue
    e ->
      if failure_count >= 3 do
        Logger.debug("failed to load module #{inspect(module)} after #{failure_count} tries")

        message = """
        failed to load module #{inspect(module)} after #{failure_count} tries

        Got:

          #{Exception.message(e)}

        """

        reraise Beacon.LoaderError, [message: message], __STACKTRACE__
      else
        Logger.debug("failed to load module #{inspect(module)} for the #{failure_count + 1}, retrying...")
        :timer.sleep(100 * (failure_count * 2))
        reload_module!(module, ast, file, failure_count + 1)
      end
  end

  # too slow to run the css compiler on every test
  if Code.ensure_loaded?(Mix.Project) and Mix.env() == :test do
    @doc false
    def async_load_runtime_css(_site), do: :ok
  else
    @doc false
    def async_load_runtime_css(site) do
      send(self(), {:load_runtime_css, site})
      :ok
    end
  end

  @doc false
  def load_stylesheets(site) do
    StylesheetModuleLoader.load_stylesheets(site, Content.list_stylesheets(site))
    :ok
  end

  # TODO: replace my_component in favor of https://github.com/BeaconCMS/beacon/issues/84
  @doc false
  def load_components(site) do
    ComponentModuleLoader.load_components(site, Content.list_components(site, per_page: :infinity))
    :ok
  end

  @doc false
  def load_snippet_helpers(site) do
    SnippetModuleLoader.load_helpers(site, Content.list_snippet_helpers(site))
    :ok
  end

  @doc false
  def load_layouts(site) do
    site
    |> Content.list_published_layouts()
    |> Enum.map(fn layout ->
      Task.async(fn ->
        {:ok, _module, _ast} = LayoutModuleLoader.load_layout!(layout)
        :ok
      end)
    end)
    |> Task.await_many(30_000)

    :ok
  end

  @doc false
  def load_pages(site) do
    site
    |> Content.list_published_pages()
    |> Enum.map(fn page ->
      Task.async(fn ->
        {:ok, _module, _ast} = PageModuleLoader.load_page!(page)
        :ok
      end)
    end)
    |> Task.await_many(60_000)

    :ok
  end

  defp load_error_pages(site) do
    error_pages = Content.list_error_pages(site, preloads: [:layout])
    ErrorPageModuleLoader.load_error_pages!(error_pages, site)
    :ok
  end

  @doc false
  def load_data_source(site) do
    live_data = Content.live_data_for_site(site, select: [:id, :path, assigns: [:id, :key, :value, :format]])
    DataSourceModuleLoader.load_data_source(live_data, site)
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
  def error_module_for_site(site) do
    module_for_site(site, "ErrorPages")
  end

  @doc false
  def data_source_module_for_site(site) do
    module_for_site(site, "DataSource")
  end

  @doc false
  def snippet_helpers_module_for_site(site) do
    module_for_site(site, "SnippetHelpers")
  end

  @doc false
  def layout_module_for_site(layout_id) do
    module_for_site("Layout#{layout_id}")
  end

  @doc false
  def page_module_for_site(page_id) do
    module_for_site("Page#{page_id}")
  end

  defp module_for_site(resource) do
    Module.concat([BeaconWeb.LiveRenderer, resource])
  end

  defp module_for_site(site, resource) do
    site_hash = :md5 |> :crypto.hash(Atom.to_string(site)) |> Base.encode16()
    Module.concat([BeaconWeb.LiveRenderer, "#{site_hash}#{resource}"])
  end

  # This retry logic exists because a module may be in the process of being reloaded, in which case we want to retry
  @doc false
  def call_function_with_retry!(module, function, args, failure_count \\ 0) when is_atom(module) and is_atom(function) and is_list(args) do
    apply(module, function, args)
  rescue
    e in UndefinedFunctionError ->
      case {failure_count, e} do
        {x, _} when x >= 10 ->
          mfa = Exception.format_mfa(module, function, length(args))
          Logger.debug("failed to call #{mfa} after #{failure_count} tries")
          reraise e, __STACKTRACE__

        {_, %UndefinedFunctionError{module: ^module, function: ^function}} ->
          mfa = Exception.format_mfa(module, function, length(args))
          Logger.debug("failed to call #{mfa} for the #{failure_count + 1} time, retrying...")
          :timer.sleep(100 * (failure_count * 2))
          call_function_with_retry!(module, function, args, failure_count + 1)

        _ ->
          reraise e, __STACKTRACE__
      end

    _e in FunctionClauseError ->
      mfa = Exception.format_mfa(module, function, length(args))

      error_message = """
      could not call #{mfa} for the given path: #{inspect(List.flatten(args))}.

      Make sure you have created a page for this path.

      See Pages.create_page!/2 for more info.
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
    result = do_load_page!(page)
    :ok = async_load_runtime_css(page.site)
    {:reply, result, config}
  end

  def handle_call({:load_page_template, page, page_module, assigns}, _from, config) do
    rendered = PageModuleLoader.load_page_template!(page, page_module, assigns)
    {:reply, rendered, config}
  end

  @doc false
  def handle_call({:unload_page, page}, _from, config) do
    PageModuleLoader.unload_page!(page)
    {:reply, page, config}
  end

  @doc false
  def handle_info({:load_runtime_css, site}, config) do
    :ok = Beacon.RuntimeCSS.load!(site)
    {:noreply, config}
  end

  @doc false
  def handle_info({:layout_published, %{site: site, id: id}}, config) do
    layout = Content.get_published_layout(site, id)

    # TODO: load only used components, depends on https://github.com/BeaconCMS/beacon/issues/84
    with :ok <- load_components(site),
         # TODO: load only used snippet helpers
         :ok <- load_snippet_helpers(site),
         {:ok, _module, _ast} <- Beacon.Loader.LayoutModuleLoader.load_layout!(layout),
         :ok <- maybe_reload_error_pages(layout),
         :ok <- async_load_runtime_css(site),
         :ok <- load_stylesheets(site) do
      :ok
    else
      _ -> raise Beacon.LoaderError, message: "failed to load resources for layout #{layout.title} of site #{layout.site}"
    end

    {:noreply, config}
  end

  @doc false
  def handle_info({:page_published, %{site: site, id: id}}, config) do
    site
    |> Content.get_published_page(id)
    |> do_load_page!()

    :ok = async_load_runtime_css(site)

    {:noreply, config}
  end

  @doc false
  def handle_info({:pages_published, site, pages}, config) do
    for page <- pages do
      site
      |> Content.get_published_page(page.id)
      |> do_load_page!()
    end

    :ok = async_load_runtime_css(site)

    {:noreply, config}
  end

  @doc false
  def handle_info({:page_unpublished, %{site: site, id: id}}, config) do
    site
    |> Content.get_published_page(id)
    |> PageModuleLoader.unload_page!()

    {:noreply, config}
  end

  @doc false
  def handle_info({:component_updated, component}, config) do
    :ok = load_components(component.site)
    :ok = Beacon.PubSub.component_loaded(component)
    :ok = async_load_runtime_css(component.site)
    {:noreply, config}
  end

  @doc false
  def handle_info({:error_page_updated, error_page}, config) do
    :ok = load_error_pages(error_page.site)
    :ok = Beacon.PubSub.error_page_loaded(error_page)
    :ok = async_load_runtime_css(error_page.site)
    {:noreply, config}
  end

  @doc false
  def handle_info(:live_data_updated, config) do
    :ok = load_data_source(config.site)
    {:noreply, config}
  end

  @doc false
  def handle_info(msg, config) do
    Logger.warning("Beacon.Loader can't handle the message: #{inspect(msg)}")
    {:noreply, config}
  end

  defp do_load_page!(page) when is_nil(page), do: nil

  defp do_load_page!(page) do
    layout = Content.get_published_layout(page.site, page.layout_id)

    # TODO: load only used components, depends on https://github.com/BeaconCMS/beacon/issues/84
    with :ok <- load_components(page.site),
         # TODO: load only used snippet helpers
         :ok <- load_snippet_helpers(page.site),
         {:ok, _module, _ast} <- LayoutModuleLoader.load_layout!(layout),
         :ok <- load_stylesheets(page.site),
         {:ok, _module, _ast} <- PageModuleLoader.load_page!(page) do
      :ok
    else
      _ -> raise Beacon.LoaderError, message: "failed to load resources for page #{page.title} of site #{page.site}"
    end
  end

  # we need to reload error pages bacause the layout is embeeded into those pages
  defp maybe_reload_error_pages(layout) do
    error_pages = Content.list_error_pages_by(layout.site, [layout_id: layout.id], per_page: :infinity, preloads: [:layout])
    ErrorPageModuleLoader.load_error_pages!(error_pages, layout.site)
    :ok
  end

  @doc false
  # https://github.com/phoenixframework/phoenix_live_view/blob/8fedc6927fd937fe381553715e723754b3596a97/lib/phoenix_live_view/channel.ex#L435-L437
  def exported?(m, f, a) do
    function_exported?(m, f, a) || (Code.ensure_loaded?(m) && function_exported?(m, f, a))
  end
end
