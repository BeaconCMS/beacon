defmodule Beacon.RuntimeRenderer.PubSubHandler do
  @moduledoc false

  # Lightweight GenServer that subscribes to content-change PubSub events
  # and updates the RuntimeRenderer's ETS store accordingly.
  #
  # This replaces the PubSub handling previously embedded in Beacon.Loader.
  # Instead of unloading/recompiling dynamic BEAM modules, it refreshes
  # the serializable IR stored in ETS via RuntimeRenderer.Loader.

  use GenServer
  require Logger

  alias Beacon.PubSub
  alias Beacon.RouterServer
  alias Beacon.RuntimeRenderer

  @css_debounce_ms 1_000

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  # ------------------------------------------------------------------
  # Server callbacks
  # ------------------------------------------------------------------

  @impl true
  def init(config) do
    state = %{config: config, css_timer: nil}

    if Beacon.Config.env_test?() do
      {:ok, state}
    else
      {:ok, state, {:continue, :async_init}}
    end
  end

  @impl true
  def handle_continue(:async_init, %{config: config} = state) do
    %{site: site} = config

    PubSub.subscribe_to_layouts(site)
    PubSub.subscribe_to_pages(site)
    PubSub.subscribe_to_content(site)

    {:noreply, state}
  end

  # ------------------------------------------------------------------
  # Layout events
  # ------------------------------------------------------------------

  @impl true
  def handle_info({:layout_published, %{site: site, id: id}}, state) do
    RuntimeRenderer.Loader.reload_layout(site, id)
    Beacon.PageRenderCache.invalidate_by_layout(site, to_string(id))
    {:noreply, schedule_css_recompilation(state, site)}
  end

  # ------------------------------------------------------------------
  # Page events
  # ------------------------------------------------------------------

  def handle_info({:page_published, %{site: site, id: id}}, state) do
    RuntimeRenderer.Loader.reload_page(site, id)
    Beacon.PageRenderCache.invalidate_page(site, to_string(id))
    {:noreply, schedule_css_recompilation(state, site)}
  end

  def handle_info({:pages_published, site, pages}, state) do
    for %{id: id} <- pages do
      RuntimeRenderer.Loader.reload_page(site, id)
      Beacon.PageRenderCache.invalidate_page(site, to_string(id))
    end

    {:noreply, schedule_css_recompilation(state, site)}
  end

  def handle_info({:page_unpublished, %{site: site, id: id, path: path}}, state) do
    RouterServer.del_page(site, path)
    RuntimeRenderer.unpublish_page(site, id)
    {:noreply, state}
  end

  # ------------------------------------------------------------------
  # Content-updated events
  # ------------------------------------------------------------------

  def handle_info({:content_updated, :stylesheet, %{site: site}}, state) do
    {:noreply, schedule_css_recompilation(state, site)}
  end

  def handle_info({:content_updated, :snippet_helper, %{site: site}}, state) do
    {:noreply, schedule_css_recompilation(state, site)}
  end

  def handle_info({:content_updated, :error_page, %{site: site}}, state) do
    {:noreply, schedule_css_recompilation(state, site)}
  end

  def handle_info({:content_updated, :component, %{site: site}}, state) do
    RuntimeRenderer.Loader.load_components(site)
    # Component invalidation is handled directly by Content.update_component
    # which calls PageRenderCache.invalidate_by_component with the specific name.
    # Here we only need to reload the component IR into ETS.
    {:noreply, schedule_css_recompilation(state, site)}
  end

  def handle_info({:content_updated, :live_data, %{site: site}}, state) do
    RuntimeRenderer.clear_live_data_cache(site)
    # Notify all connected LiveViews that live data changed.
    # We invalidate all loaded pages since live_data paths use pattern
    # matching and we can't efficiently determine which pages are affected.
    invalidate_all_loaded_pages(site)
    {:noreply, state}
  end

  def handle_info({:content_updated, :info_handler, %{site: site}}, state) do
    RuntimeRenderer.Loader.reload_info_handlers(site)
    {:noreply, state}
  end

  def handle_info({:content_updated, :event_handler, %{site: site}}, state) do
    RuntimeRenderer.Loader.reload_event_handlers(site)
    {:noreply, state}
  end

  def handle_info({:content_updated, :js_hook, %{site: site}}, state) do
    # Invalidate the JS compile cache and recompile
    :ets.delete(:beacon_assets, {site, :js_compile})
    Beacon.RuntimeJS.load!(site)
    {:noreply, state}
  end

  # ------------------------------------------------------------------
  # CSS debounce timer
  # ------------------------------------------------------------------

  def handle_info({:recompile_css, site}, state) do
    # Invalidate ETS cache and recompile via Zig NIF
    :ets.delete(:beacon_assets, {site, :css})
    :ets.delete(:beacon_assets, {site, :css_compile})

    try do
      Beacon.RuntimeCSS.load!(site)
    rescue
      error ->
        Logger.warning("[Beacon.CSS] CSS recompilation failed for #{site}: #{Exception.message(error)}")
    end

    {:noreply, %{state | css_timer: nil}}
  end

  # ------------------------------------------------------------------
  # Catch-all
  # ------------------------------------------------------------------

  def handle_info(msg, state) do
    Logger.warning("Beacon.RuntimeRenderer.PubSubHandler cannot handle message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp invalidate_all_loaded_pages(site) do
    table = :beacon_runtime_poc

    # Scan ETS for all manifests belonging to this site
    :ets.match(table, {{site, :"$1", :manifest}, :"$2"})
    |> Enum.each(fn [page_id, _manifest] ->
      Beacon.PageRenderCache.invalidate_page(site, page_id)
    end)
  end

  defp schedule_css_recompilation(%{css_timer: timer} = state, site) do
    if timer, do: Process.cancel_timer(timer)
    new_timer = Process.send_after(self(), {:recompile_css, site}, @css_debounce_ms)
    %{state | css_timer: new_timer}
  end
end
