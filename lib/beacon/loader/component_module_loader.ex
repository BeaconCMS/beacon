defmodule Beacon.Loader.ComponentModuleLoader do
  require Logger

  alias Beacon.Components.Component
  alias Beacon.Loader.ModuleLoader

  def load_components(site, components) do
    component_module = Beacon.Loader.component_module_for_site(site)

    render_functions = Enum.map(components, &render_component/1)

    code_string = render(component_module, render_functions)
    Logger.debug("Loading components: \n#{code_string}")

    with :error <- ModuleLoader.load(component_module, code_string) do
        Logger.error("Skipping the last component and attempting with the others...")
        load_components(site, Enum.drop(components, -1))
    end

    {:ok, code_string}
  end

  defp render(component_module, render_functions) do
    """
    defmodule #{component_module} do
      import Phoenix.LiveView.Helpers
      use Phoenix.HTML

      def my_component(name, assigns \\\\ []), do: render(name, Enum.into(assigns, %{}))

    #{Enum.join(render_functions, "\n")}
    end
    """
  end

  defp render_component(%Component{name: name, body: body}) do
    Beacon.Util.safe_code_heex_check!(body)

    """
      def render(#{inspect(name)}, assigns) do
    #{~s(~H""")}
    #{body}
    #{~s(""")}
      end

    """
  end
end
