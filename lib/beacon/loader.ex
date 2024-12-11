defmodule Beacon.Loader do
  @moduledoc false

  use GenServer
  require Logger
  alias Beacon.Content
  alias Beacon.Loader
  alias Beacon.PubSub
  alias Beacon.RouterServer

  @timeout :timer.seconds(15)

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  def init(config) do
    if Beacon.Config.env_test?() do
      {:ok, config}
    else
      {:ok, config, {:continue, :async_init}}
    end
  end

  def safe_apply_mfa(site, module, function, args, opts \\ []) do
    if :erlang.module_loaded(module) do
      apply(module, function, args)
    else
      case GenServer.call(worker(site), {:apply_mfa, module, function, args}) do
        {:ok, result} ->
          result

        {:error, error, stacktrace} ->
          raise_invoke_error(site, error, module, function, args, opts[:context], stacktrace)
      end
    end
  rescue
    error ->
      if live_data_module?(module) do
        # LiveData is user-provided code, which always has the possibility of errors.
        # In this case, we want to ensure the original error is surfaced to the user for easier debugging.
        reraise error, __STACKTRACE__
      else
        raise_invoke_error(site, error, module, function, args, opts[:context], __STACKTRACE__)
      end
  end

  defp raise_invoke_error(site, error, module, function, args, context, stacktrace) do
    reraise Beacon.InvokeError, [site: site, error: error, module: module, function: function, args: args, context: context], stacktrace
  end

  defp live_data_module?(module) do
    case module |> Module.split() |> List.last() do
      "LiveData" -> true
      _ -> false
    end
  end

  defp worker(site) do
    supervisor = Beacon.Registry.via({site, Beacon.LoaderSupervisor})
    config = %{site: site}

    case DynamicSupervisor.start_child(supervisor, {Beacon.Loader.Worker, config}) do
      {:ok, pid} ->
        pid

      # this should never happen so that's not a rescuable error
      error ->
        raise """
        failed to start a loader worker

          Got: #{inspect(error)}

        """
    end
  end

  @doc """
  Remove OLD and move NEW to OLD.

  Existing processes can continue using OLD while making room for NEW version.
  """
  def unload(module) when is_atom(module) do
    :code.purge(module)
    :code.delete(module)
    :ok
  end

  def unload(_module), do: :skip

  # Client

  def module_name(site, resource) do
    site_hash =
      :md5
      |> :crypto.hash(Atom.to_string(site))
      |> Base.encode16(case: :lower)

    Module.concat([Beacon.Web.LiveRenderer, "#{site_hash}", "#{resource}"])
  end

  def ping(site) do
    GenServer.call(worker(site), :ping, @timeout)
  end

  def populate_default_media(site) do
    GenServer.call(worker(site), :populate_default_media, @timeout)
  end

  def populate_default_components(site) do
    GenServer.call(worker(site), :populate_default_components, @timeout)
  end

  def populate_default_layouts(site) do
    GenServer.call(worker(site), :populate_default_layouts, @timeout)
  end

  def populate_default_error_pages(site) do
    GenServer.call(worker(site), :populate_default_error_pages, @timeout)
  end

  def populate_default_home_page(site) do
    GenServer.call(worker(site), :populate_default_home_page, @timeout)
  end

  def load_runtime_js(site) do
    GenServer.call(worker(site), :load_runtime_js, :timer.minutes(2))
  end

  def load_runtime_css(site) do
    GenServer.call(worker(site), :load_runtime_css, :timer.minutes(2))
  end

  def fetch_snippets_module(site) do
    Loader.Snippets.module_name(site)
  end

  def fetch_routes_module(site) do
    Loader.Routes.module_name(site)
  end

  def fetch_components_module(site) do
    Loader.Components.module_name(site)
  end

  def fetch_live_data_module(site) do
    Loader.LiveData.module_name(site)
  end

  def fetch_error_page_module(site) do
    Loader.ErrorPage.module_name(site)
  end

  def fetch_stylesheet_module(site) do
    Loader.Stylesheet.module_name(site)
  end

  def fetch_event_handlers_module(site) do
    Loader.EventHandlers.module_name(site)
  end

  def fetch_layouts_modules(site) do
    Enum.map(Content.list_published_layouts(site), fn layout ->
      fetch_layout_module(layout.site, layout.id)
    end)
  end

  def fetch_layout_module(site, layout_id) do
    Loader.Layout.module_name(site, layout_id)
  end

  def fetch_pages_modules(site) do
    Enum.map(Content.list_published_pages(site, per_page: :infinity), fn page ->
      fetch_page_module(page.site, page.id)
    end)
  end

  def fetch_page_module(site, page_id) do
    Loader.Page.module_name(site, page_id)
  end

  def fetch_info_handlers_module(site) do
    Loader.InfoHandlers.module_name(site)
  end

  def load_snippets_module(site) do
    call_worker(site, :load_snippets_module, {:load_snippets_module, [site]})
  end

  def load_routes_module(site) do
    call_worker(site, :load_routes_module, {:load_routes_module, [site]})
  end

  def load_components_module(site) do
    call_worker(site, :load_components_module, {:load_components_module, [site]})
  end

  def load_live_data_module(site) do
    call_worker(site, :load_live_data_module, {:load_live_data_module, [site]})
  end

  def load_error_page_module(site) do
    call_worker(site, :load_error_page_module, {:load_error_page_module, [site]})
  end

  def load_stylesheet_module(site) do
    call_worker(site, :load_stylesheet_module, {:load_stylesheet_module, [site]})
  end

  def load_event_handlers_module(site) do
    call_worker(site, :load_event_handlers_module, {:load_event_handlers_module, [site]})
  end

  def load_info_handlers_module(site) do
    call_worker(site, :load_info_handlers_module, {:load_info_handlers_module, [site]})
  end

  def load_layouts_modules(site) do
    site
    |> Content.list_published_layouts()
    |> Enum.map(&load_layout_module(&1.site, &1.id))
  end

  def load_layout_module(site, layout_id) do
    call_worker(site, {:load_layout_module, layout_id}, {:load_layout_module, [site, layout_id]})
  end

  def load_pages_modules(site, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, :infinity)

    site
    |> Content.list_published_pages(per_page: per_page)
    |> Enum.map(&load_page_module(&1.site, &1.id))
  end

  def load_page_module(site, page_id) do
    call_worker(site, {:load_page_module, page_id}, {:load_page_module, [site, page_id]})
  end

  # call worker asyncly or syncly depending on the current site mode
  # or skip if mode is manual so we don't load modules
  defp call_worker(site, async_request, sync_request) do
    mode = Beacon.Config.fetch!(site).mode

    case mode do
      :live ->
        GenServer.call(worker(site), async_request, @timeout)

      :testing ->
        {sync_fun, sync_args} = sync_request
        apply(Beacon.Loader.Worker, sync_fun, sync_args)

      :manual ->
        :skip
    end
  end

  def unload_page_module(site, page_id) do
    GenServer.call(worker(site), {:unload_page_module, page_id}, @timeout)
  end

  def ensure_loaded!(modules, site) do
    Beacon.ErrorHandler.enable(site)
    Enum.each(modules, & &1.__info__(:module))
  end

  # Server

  def handle_continue(:async_init, config) do
    %{site: site} = config

    PubSub.subscribe_to_layouts(site)
    PubSub.subscribe_to_pages(site)
    PubSub.subscribe_to_content(site)

    {:noreply, config}
  end

  # Published resources are just unloaded so `Beacon.ErrorHandler`
  # takes care of loading them on the next request.

  def handle_info({:layout_published, %{site: site, id: id}}, config) do
    Beacon.Content.reset_published_layout(site, id)

    site
    |> Loader.Layout.module_name(id)
    |> unload()

    load_runtime_css(site)

    {:noreply, config}
  end

  def handle_info({:page_published, %{site: site, id: id}}, config) do
    Beacon.Content.reset_published_page(site, id)

    site
    |> Loader.Page.module_name(id)
    |> unload()

    load_runtime_css(site)

    {:noreply, config}
  end

  def handle_info({:pages_published, site, pages}, config) do
    for %{id: id} <- pages do
      Beacon.Content.reset_published_page(site, id)

      site
      |> Loader.Page.module_name(id)
      |> unload()
    end

    load_runtime_css(site)

    {:noreply, config}
  end

  def handle_info({:page_unpublished, %{site: site, id: id, path: path}}, config) do
    RouterServer.del_page(site, path)
    unload_page_module(site, id)
    {:noreply, config}
  end

  def handle_info({:content_updated, :stylesheet, %{site: site}}, config) do
    site
    |> Loader.Stylesheet.module_name()
    |> unload()

    load_runtime_css(site)

    {:noreply, config}
  end

  def handle_info({:content_updated, :snippet_helper, %{site: site}}, config) do
    site
    |> Loader.Snippets.module_name()
    |> unload()

    load_runtime_css(site)

    {:noreply, config}
  end

  def handle_info({:content_updated, :error_page, %{site: site}}, config) do
    site
    |> Loader.ErrorPage.module_name()
    |> unload()

    load_runtime_css(site)

    {:noreply, config}
  end

  def handle_info({:content_updated, :component, %{site: site}}, config) do
    site
    |> Loader.Components.module_name()
    |> unload()

    # consider implementing HTML and Tag engines
    # to intercept component module calls
    if config.mode != :manual, do: load_components_module(site)

    load_runtime_css(site)

    {:noreply, config}
  end

  def handle_info({:content_updated, :live_data, %{site: site}}, config) do
    site
    |> Loader.LiveData.module_name()
    |> unload()

    load_runtime_css(site)

    {:noreply, config}
  end

  def handle_info({:content_updated, :info_handler, %{site: site}}, config) do
    site
    |> Loader.InfoHandlers.module_name()
    |> unload()

    {:noreply, config}
  end

  def handle_info({:content_updated, :event_handler, %{site: site}}, config) do
    site
    |> Loader.EventHandlers.module_name()
    |> unload()

    {:noreply, config}
  end

  def handle_info(msg, config) do
    raise inspect(msg)
    Logger.warning("Beacon.Loader can not handle the message: #{inspect(msg)}")
    {:noreply, config}
  end
end
