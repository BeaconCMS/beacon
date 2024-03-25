defmodule Beacon.Loader.Stylesheet do
  @moduledoc false

  alias Beacon.Loader

  def module_name(site), do: Loader.module_name(site, "Stylesheet")

  def build_ast(site, stylesheets) do
    site
    |> module_name()
    |> render_module(stylesheets)
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

  defp render_stylesheet(%{name: name, content: content}) do
    """
    /* #{name} */

    #{content}
    """
  end
end
