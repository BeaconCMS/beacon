defmodule Beacon.Loader do
  @moduledoc false

  use GenServer
  require Logger

  defmodule Error do
    # Using `plug_status` for rendering this exception as 404 in production.
    # More info: https://hexdocs.pm/phoenix/custom_error_pages.html#custom-exceptions
    defexception message: "Error in Beacon.Loader", plug_status: 404
  end

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  def init(config) do
    load_from_db(config.site)
    {:ok, config}
  end

  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  def reload_site(site) do
    config = Beacon.Config.fetch!(site)
    GenServer.call(name(config.site), {:reload_site, config.site})
  end

  # TODO: check results of each function pass and/or return results
  # TODO: load each group in parallel
  defp load_from_db(site) do
    :ok = Beacon.RuntimeJS.load()
    :ok = Beacon.RuntimeCSS.load_admin()
    load_runtime_css(site)
    load_components(site)
    load_layouts(site)
    load_pages(site)
    load_stylesheets(site)

    :ok
  end

  defp load_runtime_css(site) do
    # TODO: control loading by env when we get to refactor/improve Server
    if Code.ensure_loaded?(Mix.Project) and Mix.env() == :test do
      ""
    else
      Beacon.RuntimeCSS.load(site)
    end
  end

  defp load_components(site) do
    Beacon.Loader.ComponentModuleLoader.load_components(site, Beacon.Components.list_components_for_site(site))
  end

  def load_layouts(site) do
    Beacon.Loader.LayoutModuleLoader.load_layouts(site, Beacon.Layouts.list_layouts_for_site(site))
  end

  def load_pages(site) do
    pages = Beacon.Pages.list_pages_for_site(site, [:events, :helpers])
    module = Beacon.Loader.PageModuleLoader.load_templates(site, pages)
    Enum.each(pages, &Beacon.PubSub.broadcast_page_update(site, &1.path))

    module
  end

  def load_stylesheets(site) do
    Beacon.Loader.StylesheetModuleLoader.load_stylesheets(site, Beacon.Stylesheets.list_stylesheets_for_site(site))
  end

  def page_module_for_site(site) do
    module_for_site(site, "Page")
  end

  def component_module_for_site(site) do
    module_for_site(site, "Component")
  end

  def layout_module_for_site(site) do
    module_for_site(site, "Layout")
  end

  def stylesheet_module_for_site(site) do
    module_for_site(site, "Stylesheet")
  end

  defp module_for_site(site, prefix) do
    site_hash = :crypto.hash(:md5, Atom.to_string(site)) |> Base.encode16()
    Module.concat([BeaconWeb.LiveRenderer, "#{prefix}#{site_hash}"])
  end

  # This retry logic exists because a module may be in the process of being reloaded, in which case we want to retry
  def call_function_with_retry(module, function, args, failure_count \\ 0) do
    apply(module, function, args)
  rescue
    e in UndefinedFunctionError ->
      case {failure_count, e} do
        {x, _} when x >= 10 ->
          Logger.debug("Failed to call #{inspect(module)} #{inspect(function)} 10 times.")
          reraise e, __STACKTRACE__

        {_, %UndefinedFunctionError{function: ^function, module: ^module}} ->
          Logger.debug("Failed to call #{inspect(module)} #{inspect(function)} with #{inspect(args)} for the #{failure_count + 1} time. Retrying.")
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

      reraise __MODULE__.Error, [message: error_message], __STACKTRACE__

    e ->
      reraise e, __STACKTRACE__
  end

  def compile_template!(site, file, template) do
    Beacon.safe_code_heex_check!(site, template)

    if Code.ensure_loaded?(Phoenix.LiveView.TagEngine) do
      EEx.compile_string(template,
        engine: Phoenix.LiveView.TagEngine,
        line: 1,
        file: file,
        caller: __ENV__,
        source: template,
        trim: true,
        tag_handler: Phoenix.LiveView.HTMLEngine
      )
    else
      EEx.compile_string(template,
        engine: Phoenix.LiveView.HTMLEngine,
        line: 1,
        file: file,
        caller: __ENV__,
        source: template,
        trim: true
      )
    end
  end

  def handle_call({:reload_site, site}, _from, config) do
    load_from_db(site)
    {:reply, :ok, config}
  end
end
