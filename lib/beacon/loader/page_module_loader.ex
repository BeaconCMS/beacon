defmodule Beacon.Loader.PageModuleLoader do
  require Logger

  alias Beacon.Loader.ModuleLoader
  alias Beacon.Pages.Page
  alias Beacon.Pages.PageEvent
  alias Beacon.Pages.PageHelper

  def load_templates(site, pages) do
    page_module = Beacon.Loader.page_module_for_site(site)
    component_module = Beacon.Loader.component_module_for_site(site)

    # Group function heads together to avoid compiler warnings
    functions =
      for fun <- [&render_page/1, &page_assigns/1, &page_id/1, &layout_id_for_path/1, &handle_event/1, &helper/1, &dynamic_helper/1],
          page <- pages do
        fun.(page)
      end ++ [page_module(page_module)]

    code_string = render(page_module, component_module, functions)

    Logger.debug("Loading template: \n#{code_string}")
    :ok = ModuleLoader.load(page_module, code_string)
    {:ok, code_string}
  end

  defp render(module_name, component_module, functions) do
    """
    defmodule #{module_name} do
      import Phoenix.Component
      #{ModuleLoader.import_my_component(component_module, functions)}
      use Phoenix.HTML

      #{Enum.join(functions, "\n")}
    end
    """
  end

  defp render_page(%Page{path: path, template: template}) do
    Beacon.Util.safe_code_heex_check!(template)

    """
      def render(#{path_to_args(path, "")}, assigns) do
        assigns = assign(assigns, :beacon_path_params, #{path_params(path)})
    #{~s(~H""")}
    #{template}
    #{~s(""")}
      end
    """
  end

  defp page_assigns(%Page{id: id, meta_tags: meta_tags}) do
    """
      def page_assigns(#{inspect(id)}) do
        %{ meta_tags: #{inspect(meta_tags)} }
      end
    """
  end

  defp page_id(%Page{id: id, path: path}) do
    """
      def page_id(#{path_to_args(path, "")}), do: #{inspect(id)}
    """
  end

  defp layout_id_for_path(%Page{path: path, layout_id: layout_id}) do
    """
      def layout_id_for_path(#{path_to_args(path, "_")}), do: #{inspect(layout_id)}
    """
  end

  defp page_module(page_module) do
    """
      def page_module do
        String.to_atom("#{page_module}")
      end
    """
  end

  defp handle_event(%Page{path: path, events: events}) do
    Enum.map(events, fn %PageEvent{} = event ->
      Beacon.Util.safe_code_check!(event.code)

      """
        def handle_event(#{path_to_args(path, "")}, "#{event.event_name}", event_params, socket) do
          #{event.code}
        end
      """
    end)
  end

  # TODO: validate fn name and args
  def helper(%Page{helpers: helpers}) do
    Enum.map(helpers, fn %PageHelper{} = helper ->
      Beacon.Util.safe_code_check!(helper.code)

      """
        def #{helper.helper_name}(#{helper.helper_args}) do
          #{helper.code}
        end
      """
    end)
  end

  defp dynamic_helper(_) do
    """
      def dynamic_helper(helper_name, args) do
        Beacon.Loader.call_function_with_retry(page_module(), String.to_atom(helper_name), [args])
      end
    """
  end

  defp path_to_args("", _), do: "[]"

  defp path_to_args(path, prefix) do
    args =
      path
      |> String.split("/")
      |> Enum.map_join(",", &path_segment_to_arg(&1, prefix))
      |> String.replace(",|", " |")

    "[#{args}]"
  end

  def path_params(path) do
    vars =
      path
      |> String.split("/")
      |> Enum.filter(&(String.starts_with?(&1, ":") or String.starts_with?(&1, "*")))
      |> Enum.map_join(", ", fn
        ":" <> var -> "#{var}: #{var}"
        "*" <> var -> "#{var}: #{var}"
      end)

    "%{#{vars}}"
  end

  defp path_segment_to_arg(":" <> segment, prefix), do: prefix <> segment
  defp path_segment_to_arg("*" <> segment, prefix), do: "| " <> prefix <> segment
  defp path_segment_to_arg(segment, _prefix), do: "\"" <> segment <> "\""
end
