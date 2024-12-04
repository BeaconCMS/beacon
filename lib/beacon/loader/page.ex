defmodule Beacon.Loader.Page do
  @moduledoc false
  alias Beacon.Content
  alias Beacon.Lifecycle
  alias Beacon.Loader
  alias Beacon.Template.HEEx

  require Logger

  def module_name(site, page_id), do: Loader.module_name(site, "Page#{page_id}")

  def build_ast(site, page) do
    module = module_name(site, page.id)
    routes_module = Loader.Routes.module_name(site)
    components_module = Loader.Components.module_name(site)

    # Group function heads together to avoid compiler warnings
    functions = [
      for fun <- [&page/1, &page_assigns/1, &handle_event/1, &handle_info/1, &helper/1] do
        fun.(page)
      end,
      render(page),
      dynamic_helper(site)
    ]

    # `import` modules won't be autoloaded
    Loader.ensure_loaded!([routes_module, components_module], site)

    ast = build(module, routes_module, components_module, functions)

    {module, ast}
  end

  defp build(module_name, routes_module, components_module, functions) do
    quote do
      defmodule unquote(module_name) do
        import Phoenix.HTML
        import Phoenix.HTML.Form
        import PhoenixHTMLHelpers.Form, except: [label: 1]
        import PhoenixHTMLHelpers.Link
        import PhoenixHTMLHelpers.Tag
        import PhoenixHTMLHelpers.Format
        import Phoenix.LiveView
        import Phoenix.Component, except: [assign: 2, assign: 3, assign_new: 3]
        import Beacon.Web, only: [assign: 2, assign: 3, assign_new: 3]
        import Beacon.Router, only: [beacon_asset_path: 2, beacon_asset_url: 2]
        use Gettext, backend: Beacon.Gettext
        import unquote(routes_module)
        import unquote(components_module)

        unquote_splicing(functions)
      end
    end
  end

  defp page(page) do
    quote do
      def page do
        %Beacon.Content.Page{
          site: unquote(page.site),
          id: unquote(page.id),
          layout_id: unquote(page.layout_id),
          path: unquote(page.path),
          title: unquote(page.title),
          format: unquote(page.format)
        }
      end
    end
  end

  defp page_assigns(page) do
    raw_schema = interpolate_raw_schema(page)

    quote do
      def page_assigns do
        %{
          id: unquote(page.id),
          site: unquote(page.site),
          layout_id: unquote(page.layout_id),
          title: unquote(page.title),
          meta_tags: unquote(Macro.escape(page.meta_tags)),
          raw_schema: unquote(Macro.escape(raw_schema)),
          path: unquote(page.path),
          description: unquote(page.description),
          order: unquote(page.order),
          format: unquote(page.format),
          extra: unquote(Macro.escape(page.extra))
        }
      end

      def page_assigns(keys) when is_list(keys) do
        Map.take(page_assigns(), keys)
      end
    end
  end

  def interpolate_raw_schema(page) do
    page.raw_schema
    |> List.wrap()
    |> Enum.map(&interpolate_raw_schema_record(&1, page))
  end

  defp interpolate_raw_schema_record(schema, page) when is_map(schema) do
    render = fn key, value, page ->
      case Content.render_snippet(value, %{page: page, live_data: %{}}) do
        {:ok, new_value} ->
          {key, new_value}

        {:error, error} ->
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
    event_handlers = Content.list_event_handlers(page.site)

    Enum.map(event_handlers, fn event_handler ->
      Beacon.safe_code_check!(page.site, event_handler.code)

      quote do
        def handle_event(unquote(event_handler.name), var!(event_params), var!(socket)) do
          unquote(Code.string_to_quoted!(event_handler.code))
        end
      end
    end)
  end

  defp handle_info(page) do
    %{site: site} = page

    info_handlers = Content.list_info_handlers(site)

    Enum.map(info_handlers, fn info_handler ->
      Beacon.safe_code_check!(site, info_handler.code)

      quote do
        def handle_info(unquote(Code.string_to_quoted!(info_handler.msg)), var!(socket)) do
          unquote(Code.string_to_quoted!(info_handler.code))
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

  defp render(page) do
    primary_template = Lifecycle.Template.load_template(page)
    {:ok, primary} = HEEx.compile(page.site, page.path, primary_template)

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
            |> Beacon.Template.choose_template(var!(assigns).beacon.private[:variant_roll])
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

  defp load_variants(%{variants: variants} = page) when is_list(variants) do
    for variant <- variants do
      page = %{page | template: variant.template}
      template = Lifecycle.Template.load_template(page)
      {:ok, ast} = HEEx.compile(page.site, page.path, template)

      [
        variant.name,
        variant.weight,
        ast
      ]
    end
  end

  defp load_variants(page), do: raise(Beacon.LoaderError, message: "failed to load variants for page #{page.id} - #{page.path}")

  defp dynamic_helper(site) do
    quote do
      def dynamic_helper(helper_name, args) do
        Beacon.apply_mfa(unquote(site), __MODULE__, String.to_atom(helper_name), [args])
      end
    end
  end
end
