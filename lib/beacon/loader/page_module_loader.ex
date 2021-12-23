defmodule Beacon.Loader.PageModuleLoader do
  require Logger

  alias Beacon.Loader.ModuleLoader
  alias Beacon.Pages.Page

  def load_templates(site, pages) do
    page_module = Beacon.Loader.page_module_for_site(site)
    component_module = Beacon.Loader.component_module_for_site(site)

    render_functions = Enum.map(pages, &render_page/1)

    code_string = render(page_module, component_module, render_functions)
    Logger.debug("Loading template: \n#{code_string}")
    :ok = ModuleLoader.load(page_module, code_string)
    {:ok, code_string}
  end

  defp render(module_name, component_module, render_functions) do
    """
    defmodule #{module_name} do
      import Phoenix.LiveView.Helpers
      use Phoenix.HTML
      alias BeaconWeb.Router.Helpers, as: Routes
      alias #{component_module}, as: Components

      def my_component(name, assigns), do: Components.render(name, Enum.into(assigns, %{}))

    #{Enum.join(render_functions, "\n")}
    end
    """
  end

  defp render_page(%Page{path: path, layout_id: layout_id, template: template}) do
    """
      def render(#{inspect(path)}, live_data, assigns) do
    #{~s(~H""")}
    #{template}
    #{~s(""")}
      end

      def layout_id_for_path(#{inspect(path)}), do: #{inspect(layout_id)}

    """
  end
end
