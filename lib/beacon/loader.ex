defmodule Beacon.Loader do
  @moduledoc false

  use GenServer
  require Logger
  alias Beacon.Content
  alias Beacon.Loader
  alias Beacon.PubSub
  alias Beacon.RouterServer

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  def modules_table_name(site) do
    String.to_atom("beacon_modules_#{site}")
  end

  def resources_table_name(site) do
    String.to_atom("beacon_resources_#{site}")
  end

  def init(config) do
    :ets.new(modules_table_name(config.site), [:ordered_set, :named_table, :public, read_concurrency: true])
    :ets.new(resources_table_name(config.site), [:ordered_set, :named_table, :public, read_concurrency: true])

    if Beacon.Config.env_test?() do
      {:ok, config}
    else
      {:ok, config, {:continue, :async_init}}
    end
  end

  def terminate(_reason, config) do
    :ets.delete(modules_table_name(config.site))
    :ets.delete(resources_table_name(config.site))
    :ok
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

  # Client

  def module_name(site, resource) do
    site_hash = :md5 |> :crypto.hash(Atom.to_string(site)) |> Base.encode16(case: :lower)
    Module.concat([BeaconWeb.LiveRenderer, "#{site_hash}", "#{resource}"])
  end

  def ping(site) do
    GenServer.call(worker(site), :ping)
  end

  def add_module(site, module, {_md5, _error, _diagnostics} = metadata) when is_atom(site) do
    :ets.insert(modules_table_name(site), {module, metadata})
    :ok
  end

  def lookup_module(site, module) when is_atom(site) do
    match = {module, :_}
    guards = []
    body = [:"$_"]

    case :ets.select(modules_table_name(site), [{match, guards, body}]) do
      [match] -> match
      _ -> nil
    end
  end

  def dump_modules(site) when is_atom(site) do
    site |> modules_table_name() |> :ets.match(:"$1") |> List.flatten()
  end

  def populate_default_components(site) do
    GenServer.call(worker(site), :populate_default_components)
  end

  def populate_default_layouts(site) do
    GenServer.call(worker(site), :populate_default_layouts)
  end

  def populate_default_error_pages(site) do
    GenServer.call(worker(site), :populate_default_error_pages)
  end

  def populate_default_home_page(site) do
    GenServer.call(worker(site), :populate_default_home_page)
  end

  def reload_runtime_js(site) do
    GenServer.call(worker(site), :reload_runtime_js, :timer.minutes(5))
  end

  def reload_runtime_css(site) do
    GenServer.call(worker(site), :reload_runtime_css, :timer.minutes(5))
  end

  def fetch_snippets_module(site) do
    maybe_reload(Loader.Snippets.module_name(site), fn -> reload_snippets_module(site) end)
  end

  def fetch_components_module(site) do
    maybe_reload(Loader.Components.module_name(site), fn -> reload_components_module(site) end)
  end

  def fetch_live_data_module(site) do
    maybe_reload(Loader.LiveData.module_name(site), fn -> reload_live_data_module(site) end)
  end

  def fetch_error_page_module(site) do
    maybe_reload(Loader.ErrorPage.module_name(site), fn -> reload_error_page_module(site) end)
  end

  def fetch_stylesheet_module(site) do
    maybe_reload(Loader.Stylesheet.module_name(site), fn -> reload_stylesheet_module(site) end)
  end

  def fetch_layouts_modules(site) do
    Enum.map(Content.list_published_layouts(site), fn layout ->
      fetch_layout_module(layout.site, layout.id)
    end)
  end

  def fetch_layout_module(site, layout_id) do
    maybe_reload(Loader.Layout.module_name(site, layout_id), fn -> reload_layout_module(site, layout_id) end)
  end

  def fetch_pages_modules(site) do
    Enum.map(Content.list_published_pages(site, per_page: :infinity), fn page ->
      fetch_page_module(page.site, page.id)
    end)
  end

  def fetch_page_module(site, page_id) do
    maybe_reload(Loader.Page.module_name(site, page_id), fn -> reload_page_module(site, page_id) end)
  end

  def reload_snippets_module(site) do
    GenServer.call(worker(site), :reload_snippets_module)
  end

  def reload_components_module(site) do
    GenServer.call(worker(site), :reload_components_module)
  end

  def reload_live_data_module(site) do
    GenServer.call(worker(site), :reload_live_data_module)
  end

  def reload_error_page_module(site) do
    GenServer.call(worker(site), :reload_error_page_module)
  end

  def reload_stylesheet_module(site) do
    GenServer.call(worker(site), :reload_stylesheet_module)
  end

  def reload_layouts_modules(site) do
    Enum.map(Content.list_published_layouts(site), &reload_layout_module(&1.site, &1.id))
  end

  def reload_layout_module(site, layout_id) do
    GenServer.call(worker(site), {:reload_layout_module, layout_id})
  end

  def reload_pages_modules(site, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, :infinity)
    Enum.map(Content.list_published_pages(site, per_page: per_page), &reload_page_module(&1.site, &1.id))
  end

  def reload_page_module(site, page_id) do
    GenServer.call(worker(site), {:reload_page_module, page_id})
  end

  def unload_page_module(site, page_id) do
    GenServer.call(worker(site), {:unload_page_module, page_id})
  end

  defp maybe_reload(module, reload_fun) do
    if :erlang.module_loaded(module) do
      module
    else
      reload_fun.()
    end
  end

  # Server

  def handle_continue(:async_init, config) do
    %{site: site} = config

    PubSub.subscribe_to_layouts(site)
    PubSub.subscribe_to_pages(site)
    PubSub.subscribe_to_content(site)

    {:noreply, config}
  end

  def handle_info({:layout_published, %{site: site, id: id}}, config) do
    reload_layout_module(site, id)
    reload_runtime_css(site)
    {:noreply, config}
  end

  def handle_info({:page_published, %{site: site, id: id}}, config) do
    reload_page_module(site, id)
    reload_runtime_css(site)
    {:noreply, config}
  end

  def handle_info({:pages_published, site, pages}, config) do
    for %{id: id} <- pages do
      reload_page_module(site, id)
    end

    reload_runtime_css(site)

    {:noreply, config}
  end

  def handle_info({:page_unpublished, %{site: site, id: id, path: path}}, config) do
    RouterServer.del_page(site, path)
    unload_page_module(site, id)
    {:noreply, config}
  end

  def handle_info({:content_updated, :stylesheet, %{site: site}}, config) do
    reload_stylesheet_module(site)
    reload_runtime_css(site)
    {:noreply, config}
  end

  def handle_info({:content_updated, :snippet_helper, %{site: site}}, config) do
    reload_snippets_module(site)
    reload_runtime_css(site)
    {:noreply, config}
  end

  def handle_info({:content_updated, :error_page, %{site: site}}, config) do
    reload_error_page_module(site)
    reload_runtime_css(site)
    {:noreply, config}
  end

  def handle_info({:content_updated, :component, %{site: site}}, config) do
    reload_components_module(site)
    reload_runtime_css(site)
    {:noreply, config}
  end

  def handle_info({:content_updated, :live_data, %{site: site}}, config) do
    reload_live_data_module(site)
    reload_runtime_css(site)
    {:noreply, config}
  end

  def handle_info(msg, config) do
    raise inspect(msg)
    Logger.warning("Beacon.Loader can not handle the message: #{inspect(msg)}")
    {:noreply, config}
  end
end
