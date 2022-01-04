defmodule Beacon.Loader.StylesheetModuleLoader do
  require Logger

  alias Beacon.Loader.ModuleLoader
  alias Beacon.Stylesheets.Stylesheet

  def load_stylesheets(site, stylesheets) do
    stylesheet_module = Beacon.Loader.stylesheet_module_for_site(site)

    code_string = render_module(stylesheet_module, stylesheets)
    Logger.debug("Loading stylesheets: \n#{code_string}")
    :ok = ModuleLoader.load(stylesheet_module, code_string)
    {:ok, code_string}
  end

  defp render_module(stylesheet_module, stylesheets) do
    """
    defmodule #{stylesheet_module} do
      def render do
        #{render_stylesheets(stylesheets)}
      end
    end
    """
  end

  defp render_stylesheets([]), do: ""

  defp render_stylesheets(stylesheets) do
    sheets = Enum.map_join(stylesheets, "\n\n", &render_stylesheet/1)

    """
    #{~s(""")}
    <style type="text/css">
      #{sheets}
    </style>
    #{~s(""")}
    """
  end

  defp render_stylesheet(%Stylesheet{name: name, content: content}) do
    """
    /* #{name} */

    #{content}
    """
  end
end
