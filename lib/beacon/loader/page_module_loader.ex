defmodule Beacon.Loader.PageModuleLoader do
  require Logger

  alias Beacon.Loader.ModuleLoader
  alias Beacon.Pages.Page

  def load_templates(site, pages) do
    page_module = Beacon.Loader.page_module_for_site(site)
    component_module = Beacon.Loader.component_module_for_site(site)

    # Group function heads together to avoid compiler warnings
    functions =
      for fun <- [&render_page/1, &layout_id_for_path/1],
          page <- pages do
        fun.(page)
      end

    code_string = render(page_module, component_module, functions)
    Logger.debug("Loading template: \n#{code_string}")
    :ok = ModuleLoader.load(page_module, code_string)
    {:ok, code_string}
  end

  defp render(module_name, component_module, functions) do
    """
    defmodule #{module_name} do
      import Phoenix.LiveView.Helpers
      #{ModuleLoader.import_my_component(component_module, functions)}
      use Phoenix.HTML

      #{Enum.join(functions, "\n")}
    end
    """
  end

  defp render_page(%Page{path: path, template: template}) do
    if !Application.get_env(:beacon, :disable_safe_code, false) do
      SafeCode.Validator.validate_heex!(template, extra_function_validators: Beacon.Loader.SafeCodeImpl)
    end

    """
      def render(#{path_to_args(path, "")}, assigns) do
        assigns = assigns
        |> Phoenix.LiveView.assign(:beacon_path_params, #{path_params(path)})

    #{~s(~H""")}
    #{template}
    #{~s(""")}
      end
    """
  end

  defp layout_id_for_path(%Page{path: path, layout_id: layout_id}) do
    """
      def layout_id_for_path(#{path_to_args(path, "_")}), do: #{inspect(layout_id)}
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
      |> Enum.map(fn
        ":" <> var -> "#{var}: #{var}"
        "*" <> var -> "#{var}: #{var}"
      end)
      |> Enum.join(", ")

    "%{#{vars}}"
  end

  defp path_segment_to_arg(":" <> segment, prefix), do: prefix <> segment
  defp path_segment_to_arg("*" <> segment, prefix), do: "| " <> prefix <> segment
  defp path_segment_to_arg(segment, _prefix), do: "\"" <> segment <> "\""
end
