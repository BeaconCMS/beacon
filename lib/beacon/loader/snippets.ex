defmodule Beacon.Loader.Snippets do
  @moduledoc false

  alias Beacon.Loader

  def module_name(site), do: Loader.module_name(site, "Snippets")

  def build_ast(site, snippets) do
    module = module_name(site)
    functions = Enum.map(snippets, &helper/1)
    render(module, functions)
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
