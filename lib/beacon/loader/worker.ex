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
    live_data = Content.live_data_for_site(site, select: [:id, :site, :path, assigns: [:id, :key, :value, :format]])
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
