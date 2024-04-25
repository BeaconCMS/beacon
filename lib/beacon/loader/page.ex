defmodule Beacon.Loader.Page do
  @moduledoc false

  require Logger
  alias Beacon.Lifecycle
  alias Beacon.Loader
  alias Beacon.Template.HEEx

  def module_name(site, page_id), do: Loader.module_name(site, "Page#{page_id}")

  def build_ast(site, page) do
    module = module_name(site, page.id)
    components_module = Loader.Components.module_name(site)

    # Group function heads together to avoid compiler warnings
    functions = [
      for fun <- [&page_assigns/1, &handle_event/1, &helper/1] do
        fun.(page)
      end,
      render(page),
      dynamic_helper()
    ]

    ast = build(module, components_module, functions)

    {module, ast}
  end

  defp build(module_name, components_module, functions) do
    quote do
      defmodule unquote(module_name) do
        use PhoenixHTMLHelpers
        import Phoenix.HTML
        import Phoenix.HTML.Form
        import Phoenix.Component
        import unquote(components_module), only: [my_component: 2]

        unquote_splicing(functions)
      end
    end
  end

  defp page_assigns(page) do
    raw_schema = interpolate_raw_schema(page)

    quote do
      def page_assigns do
        %{
          title: unquote(page.title),
          meta_tags: unquote(Macro.escape(page.meta_tags)),
          raw_schema: unquote(Macro.escape(raw_schema)),
          site: unquote(page.site),
          path: unquote(page.path),
          description: unquote(page.description),
          order: unquote(page.order),
          format: unquote(page.format),
          extra: unquote(Macro.escape(page.extra))
        }
      end
    end
  end

  defp interpolate_raw_schema(page) do
    page.raw_schema
    |> List.wrap()
    |> Enum.map(&interpolate_raw_schema_record(&1, page))
  end

  defp interpolate_raw_schema_record(schema, page) when is_map(schema) do
    render = fn key, value, page ->
      case Beacon.Content.render_snippet(value, %{page: page, live_data: %{}}) do
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

  defp dynamic_helper do
    quote do
      def dynamic_helper(helper_name, args) do
        Beacon.apply_mfa(__MODULE__, String.to_atom(helper_name), [args])
      end
    end
  end
end
