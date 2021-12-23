defmodule Beacon.Loader.LayoutModuleLoader do
  require Logger

  alias Beacon.Layouts.Layout
  alias Beacon.Loader.ModuleLoader

  def load_layouts(site, layouts) do
    module = Beacon.Loader.layout_module_for_site(site)

    render_functions =
      Enum.map(layouts, fn layout ->
        render_layout(layout)
      end)

    code_string = render(module, render_functions)
    Logger.debug("Loading layout: \n#{code_string}")
    :ok = ModuleLoader.load(module, code_string)
    {:ok, code_string}
  end

  defp render(module_name, render_functions) do
    """
    defmodule #{module_name} do
      use Phoenix.HTML
      import Phoenix.LiveView.Helpers
      alias BeaconWeb.Router.Helpers, as: Routes

    #{Enum.join(render_functions, "\n")}
    end
    """
  end

  defp render_layout(%Layout{} = layout) do
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
          stylesheets: #{inspect(layout.stylesheets)}
        }
      end
    """
  end
end
