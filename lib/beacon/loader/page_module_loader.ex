defmodule Beacon.Loader.PageModuleLoader do
  @moduledoc false

  alias Beacon.Content
  alias Beacon.Lifecycle
  alias Beacon.Loader

  require Logger

  def load_page!(%Content.Page{} = page) do
    component_module = Loader.component_module_for_site(page.site)
    page_module = Loader.page_module_for_site(page.site, page.id)

    # Group function heads together to avoid compiler warnings
    functions = [
      for fun <- [&page_assigns/1, &handle_event/1, &helper/1, &render/1] do
        fun.(page)
      end,
      dynamic_helper()
    ]

    ast = build(page_module, component_module, functions)
    :ok = Loader.reload_module!(page_module, ast)
    Beacon.Router.add_page(page.site, page.path, {page.id, page.layout_id, page.format, page_module, component_module})
    {:ok, page_module, ast}
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

  defp page_assigns(page) do
    %{id: id, meta_tags: meta_tags, title: title, raw_schema: raw_schema} = page
    meta_tags = interpolate_meta_tags(meta_tags, page)
    raw_schema = interpolate_raw_schema(raw_schema, page)

    quote do
      def page_assigns(unquote(id)) do
        %{
          title: unquote(title),
          meta_tags: unquote(Macro.escape(meta_tags)),
          raw_schema: unquote(Macro.escape(raw_schema))
        }
      end
    end
  end

  def interpolate_meta_tags(meta_tags, page) do
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

  # TODO: path_to_args in paths with dynamic segments may be broken
  defp handle_event(page) do
    %{site: site, path: path, event_handlers: event_handlers} = page

    Enum.map(event_handlers, fn event_handler ->
      Beacon.safe_code_check!(site, event_handler.code)

      quote do
        def handle_event(unquote(path_to_args(path, "")), unquote(event_handler.name), var!(event_params), var!(socket)) do
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
    primary = Lifecycle.Template.load_template(page)
    variants = load_variants(page)

    case variants do
      [] ->
        quote do
          def render(var!(assigns)) when is_map(var!(assigns)) do
            [{_, _, template}] = templates(var!(assigns))
            template
          end

          def templates(var!(assigns)) when is_map(var!(assigns)) do
            [{"primary", nil, unquote(primary)}]
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
              {"primary", nil, unquote(primary)}
              | for [name, weight, template] <- unquote(variants) do
                  {name, weight, template}
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

  defp path_to_args("", _), do: []

  defp path_to_args(path, prefix) do
    path
    |> String.split("/")
    |> Enum.map(&path_segment_to_arg(&1, prefix))
  end

  defp path_segment_to_arg(":" <> segment, prefix), do: prefix <> segment
  defp path_segment_to_arg("*" <> segment, prefix), do: "| " <> prefix <> segment
  defp path_segment_to_arg(segment, _prefix), do: segment
end
