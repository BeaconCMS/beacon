defmodule Beacon.Loader do
  @moduledoc """
  Loader is the process resposible for loading, unloading, and reloading all resources for each site.

  At start it will load all `Beacon.Content.blueprint_components/0` and existing resources stored
  in the database like layouts, pages, snippets, etc.

  When a resource is changed, for example when a page is published, it will recompile the
  modules and updated the data in ETS to make the updated resource live.

  And deleting a resource will unload it from memory.

  """
  use GenServer

  alias Beacon.Content
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
    if Code.ensure_loaded?(Mix.Project) and Mix.env() == :test do
      :skip
    else
      with :ok <- populate_components(config.site) do
        :ok = load_site_from_db(config.site)
      end
    end

    PubSub.subscribe_to_layouts(config.site)
    PubSub.subscribe_to_pages(config.site)

    {:ok, config}
  end

  # TODO: skip if components already exists
  defp populate_components(site) do
    Enum.each(Content.blueprint_components(), fn attrs -> Content.create_component!(Map.put(attrs, :site, site)) end)
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
    Beacon.Loader.ComponentModuleLoader.load_components(
      site,
      Beacon.Content.list_components(site)
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

  @doc false
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
