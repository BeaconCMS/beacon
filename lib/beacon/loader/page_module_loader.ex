defmodule Beacon.Loader.PageModuleLoader do
  require Logger
  alias Beacon.Lifecycle
  alias Beacon.Loader
  alias Beacon.Pages.Page
  alias Beacon.Pages.PageEvent
  alias Beacon.Pages.PageHelper

  def load_page!(site, page) do
    component_module = Loader.component_module_for_site(site)
    page_module = Loader.page_module_for_site(site, page.id)

    # Group function heads together to avoid compiler warnings
    functions = [
      for fun <- [&page_assigns/1, &handle_event/1, &helper/1] do
        fun.(page)
      end,
      dynamic_helper()
    ]

    ast = render(page_module, component_module, functions)
    store_page(page, page_module, component_module)
    :ok = Loader.reload_module!(page_module, ast)
    {:ok, ast}
  end

  defp render(module_name, component_module, functions) do
    quote do
      defmodule unquote(module_name) do
        use Phoenix.HTML
        import Phoenix.Component
        unquote(Loader.maybe_import_my_component(component_module, functions))

        unquote_splicing(functions)
      end
    end
  end

  defp store_page(%Page{status: :draft}, _page_module, _component_module) do
    :skip
  end

  defp store_page(%Page{} = page, page_module, component_module) do
    %{id: page_id, layout_id: layout_id, site: site, path: path} = page
    template = Lifecycle.Template.load_template(page)
    Beacon.Router.add_page(site, path, {page_id, layout_id, page.format, template, page_module, component_module})
  end

  defp page_assigns(%Page{} = page) do
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
    case Beacon.Snippets.render(value, %{page: page}) do
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
      case Beacon.Snippets.render(value, %{page: page}) do
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
  defp handle_event(%Page{site: site, path: path, events: events}) do
    Enum.map(events, fn %PageEvent{} = event ->
      Beacon.safe_code_check!(site, event.code)

      quote do
        def handle_event(unquote(path_to_args(path, "")), unquote(event.event_name), var!(event_params), var!(socket)) do
          unquote(Code.string_to_quoted!(event.code))
        end
      end
    end)
  end

  # TODO: validate fn name and args
  def helper(%Page{site: site, helpers: helpers}) do
    Enum.map(helpers, fn %PageHelper{} = helper ->
      Beacon.safe_code_check!(site, helper.code)

      args = Code.string_to_quoted!(helper.helper_args)

      quote do
        def unquote(String.to_atom(helper.helper_name))(unquote(args)) do
          unquote(Code.string_to_quoted!(helper.code))
        end
      end
    end)
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

    # |> String.replace(",|", " |")
  end

  defp path_segment_to_arg(":" <> segment, prefix), do: prefix <> segment
  defp path_segment_to_arg("*" <> segment, prefix), do: "| " <> prefix <> segment
  defp path_segment_to_arg(segment, _prefix), do: segment
end
