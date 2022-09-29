defmodule Beacon.Loader.LayoutModuleLoader do
  require Logger

  alias Beacon.Layouts.Layout
  alias Beacon.Loader.ModuleLoader

  def load_layouts(site, layouts) do
    component_module = Beacon.Loader.component_module_for_site(site)
    module = Beacon.Loader.layout_module_for_site(site)
    render_functions = Enum.map(layouts, &render_layout/1)
    code_string = render(module, render_functions, component_module)
    Logger.debug("Loading layout: \n#{code_string}")
    :ok = ModuleLoader.load(module, code_string)
    {:ok, code_string}
  end

  defp render(module_name, render_functions, component_module) do
    """
    defmodule #{module_name} do
      use Phoenix.HTML
      import Phoenix.Component
      #{ModuleLoader.import_my_component(component_module, render_functions)}

    #{Enum.join(render_functions, "\n")}
    end
    """
  end

  defp render_layout(%Layout{} = layout) do
    Beacon.Util.safe_code_heex_check!(layout.body)

    """
      def render(#{inspect(layout.id)}, assigns) do
    #{~s(~H""")}
    #{layout.body}
    #{~s(""")}
      end

      def layout_assigns(#{inspect(layout.id)}) do
        %{
          title: #{inspect(layout.title)},
          meta_tags: #{inspect(layout.meta_tags)},
          stylesheet_urls: #{inspect(layout.stylesheet_urls)}
        }
      end
    """
  end
end
