defmodule Beacon.Loader.SnippetModuleLoader do
  @moduledoc false

  alias Beacon.Loader

  def load_helpers(_site, [] = _helpers) do
    :skip
  end

  def load_helpers(site, helpers) do
    module_name = Loader.snippet_helpers_module_for_site(site)
    functions = Enum.map(helpers, &helper/1)
    ast = render(module_name, functions)
    :ok = Loader.reload_module!(module_name, ast)
    {:ok, ast}
  end

  defp render(module_name, functions) do
    quote do
      defmodule unquote(module_name) do
        (unquote_splicing(functions))
      end
    end
  end

  defp helper(helper) do
    quote do
      def unquote(String.to_atom(helper.name))(var!(assigns)) do
        unquote(Code.string_to_quoted!(helper.body))
      end
    end
  end
end
