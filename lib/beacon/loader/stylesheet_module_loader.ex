defmodule Beacon.Loader.StylesheetModuleLoader do
  require Logger

  alias Beacon.Stylesheets.Stylesheet

  def load_stylesheets(_site, [] = _stylesheets) do
    :skip
  end

  def load_stylesheets(site, stylesheets) do
    stylesheet_module = Beacon.Loader.stylesheet_module_for_site(site)

    ast = render_module(stylesheet_module, stylesheets)
    :ok = Beacon.Loader.reload_module!(stylesheet_module, ast)
    {:ok, ast}
  end

  # TODO: check if we'll be using this module to render stylesheets or if we'll rely on RuntimeCSS
  defp render_module(stylesheet_module, stylesheets) do
    quote do
      defmodule unquote(stylesheet_module) do
        def render do
          unquote(render_stylesheets(stylesheets))
        end
      end
    end
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
