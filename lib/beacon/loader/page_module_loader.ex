defmodule Beacon.Loader.PageModuleLoader do
  @moduledoc false

  use GenServer

  alias Beacon.Content
  alias Beacon.Lifecycle
  alias Beacon.Loader

  require Logger

  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: name(config.site))
  end

  def name(site) do
    Beacon.Registry.via({site, __MODULE__})
  end

  def init(config) do
    {:ok, config}
  end

  @doc """
  Reload the page module.

  `stage` can be one of:

    - `:boot` - it won't load the template, useful during app booting process
    - `:request` - it will load the template, useful during a request

  """
  if Code.ensure_loaded?(Mix.Project) and Mix.env() in [:test] do
    def load_page!(%Content.Page{} = page, stage \\ :request) do
      config = Beacon.Config.fetch!(page.site)
      GenServer.call(name(config.site), {:load_page!, page, stage}, 30_000)
    end
  else
    def load_page!(%Content.Page{} = page, stage \\ :boot) do
      config = Beacon.Config.fetch!(page.site)
      GenServer.call(name(config.site), {:load_page!, page, stage}, 30_000)
    end
  end

  def unload_page!(page) do
    config = Beacon.Config.fetch!(page.site)
    GenServer.call(name(config.site), {:unload_page!, page}, 30_000)
  end

  # TODO: retry
  @doc "Reload the page module and return the %Rendered{} template"
  def load_page_template!(%Content.Page{} = page, page_module, assigns) do
    config = Beacon.Config.fetch!(page.site)
    GenServer.call(name(config.site), {:load_page_template!, page, page_module, assigns}, 30_000)
  end

  @doc """
  Reload the page module replacing the template with a special `:not_loaded` value.

  That's useful to force the page to reload on the next request.
  """
  def unload_page_template!(%Content.Page{} = page) do
    load_page!(page, :boot)
  end

  defp build(module_name, component_module, functions) do
    quote do
      defmodule unquote(module_name) do
        use Phoenix.HTML
        import Phoenix.Component
        unquote(Loader.maybe_import_my_component(component_module, functions))

        unquote_splicing(functions)
      end
    end
  end

  ## Callbacks

  def handle_call({:load_page!, page, stage}, _from, config) do
    {:reply, do_load_page!(page, stage), config}
  end

  def handle_call({:unload_page!, page}, _from, config) do
    page_module = Loader.page_module_for_site(page.id)
    :code.delete(page_module)
    :code.purge(page_module)
    Beacon.Router.del_page(page.site, page.path)
    {:reply, {:ok, page_module}, config}
  end

  def handle_call({:load_page_template!, page, page_module, assigns}, _from, config) do
    Logger.debug("compiling #{page_module}")

    rendered =
      with %Content.Page{} = page <- Beacon.Content.get_published_page(page.site, page.id),
           {:ok, ^page_module, _ast} <- do_load_page!(page, :request),
           %Phoenix.LiveView.Rendered{} = rendered <- page_module.render(assigns) do
        rendered
      else
        _ ->
          raise Beacon.LoaderError,
            message: """
            failed to load the template for the following page:

              id: #{page.id}
              title: #{page.title}
              path: #{page.path}

            """
      end

    {:reply, rendered, config}
  end

  def do_load_page!(page, stage) do
    component_module = Loader.component_module_for_site(page.site)
    page_module = Loader.page_module_for_site(page.id)

    # Group function heads together to avoid compiler warnings
    functions = [
      for fun <- [&page_assigns/1, &handle_event/1, &helper/1] do
        fun.(page)
      end,
      render(page, stage),
      dynamic_helper()
    ]

    ast = build(page_module, component_module, functions)
    :ok = Loader.reload_module!(page_module, ast)
    Beacon.Router.add_page(page.site, page.path, {page.id, page.layout_id, page.format, page_module, component_module})

    {:ok, page_module, ast}
  end

  defp page_assigns(page) do
    %{meta_tags: meta_tags, title: title, raw_schema: raw_schema} = page
    meta_tags = interpolate_meta_tags(meta_tags, page)
    raw_schema = interpolate_raw_schema(raw_schema, page)

    quote do
      def page_assigns do
        %{
          title: unquote(title),
          meta_tags: unquote(Macro.escape(meta_tags)),
          raw_schema: unquote(Macro.escape(raw_schema))
        }
      end
    end
  end

  defp interpolate_meta_tags(meta_tags, page) do
    meta_tags
    |> List.wrap()
    |> Enum.map(&interpolate_meta_tag(&1, page))
  end

  defp interpolate_meta_tag(meta_tag, page) when is_map(meta_tag) do
    Map.new(meta_tag, &interpolate_meta_tag_attribute(&1, page))
  end

  defp interpolate_meta_tag_attribute({key, value}, page) when is_binary(value) do
    case Beacon.Content.render_snippet(value, %{page: page}) do
      {:ok, new_value} ->
        {key, new_value}

      error ->
        message = """
        failed to interpolate meta tags

        Got:

          #{inspect(error)}

        """

        raise Beacon.LoaderError, message: message
    end
  end

  defp interpolate_raw_schema(raw_schema, page) do
    raw_schema
    |> List.wrap()
    |> Enum.map(&interpolate_raw_schema_record(&1, page))
  end

  defp interpolate_raw_schema_record(schema, page) when is_map(schema) do
    render = fn key, value, page ->
      case Beacon.Content.render_snippet(value, %{page: page}) do
        {:ok, new_value} ->
          {key, new_value}

        error ->
          message = """
          failed to interpolate raw schema

          Got:

            #{inspect(error)}

          """

          raise Beacon.LoaderError, message: message
      end
    end

    Map.new(schema, fn
      {key, value} when is_binary(value) ->
        render.(key, value, page)

      {key, value} when is_map(value) ->
        {key, interpolate_raw_schema_record(value, page)}
    end)
  end

  defp handle_event(page) do
    %{site: site, event_handlers: event_handlers} = page

    Enum.map(event_handlers, fn event_handler ->
      Beacon.safe_code_check!(site, event_handler.code)

      quote do
        def handle_event(unquote(event_handler.name), var!(event_params), var!(socket)) do
          unquote(Code.string_to_quoted!(event_handler.code))
        end
      end
    end)
  end

  # TODO: validate fn name and args
  def helper(%{site: site, helpers: helpers}) do
    Enum.map(helpers, fn helper ->
      Beacon.safe_code_check!(site, helper.code)
      args = Code.string_to_quoted!(helper.args)

      quote do
        def unquote(String.to_atom(helper.name))(unquote(args)) do
          unquote(Code.string_to_quoted!(helper.code))
        end
      end
    end)
  end

  defp render(_page, :boot) do
    quote do
      def render(var!(assigns)) when is_map(var!(assigns)) do
        _ = var!(assigns)
        :not_loaded
      end
    end
  end

  defp render(page, :request) do
    primary = Lifecycle.Template.load_template(page)
    variants = load_variants(page)

    case variants do
      [] ->
        quote do
          def render(var!(assigns)) when is_map(var!(assigns)) do
            [primary] = templates(var!(assigns))
            primary
          end

          def templates(var!(assigns)) when is_map(var!(assigns)) do
            [unquote(primary)]
          end
        end

      variants ->
        quote do
          def render(var!(assigns)) when is_map(var!(assigns)) do
            var!(assigns)
            |> templates()
            |> Beacon.Template.choose_template()
          end

          def templates(var!(assigns)) when is_map(var!(assigns)) do
            [
              unquote(primary)
              | for [name, weight, template] <- unquote(variants) do
                  {weight, template}
                end
            ]
          end
        end
    end
  end

  defp load_variants(page) do
    %{variants: variants} = Beacon.Repo.preload(page, :variants)

    for variant <- variants do
      [
        variant.name,
        variant.weight,
        Lifecycle.Template.load_template(%{page | template: variant.template})
      ]
    end
  end

  defp dynamic_helper do
    quote do
      def dynamic_helper(helper_name, args) do
        Loader.call_function_with_retry(__MODULE__, String.to_atom(helper_name), [args])
      end
    end
  end
end
