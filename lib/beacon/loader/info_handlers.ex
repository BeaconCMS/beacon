defmodule Beacon.Loader.InfoHandlers do
  @moduledoc false
  alias Beacon.Loader

  def module_name(site), do: Loader.module_name(site, "InfoHandlers")

  def build_ast(site, info_handlers) do
    module = module_name(site)
    functions = Enum.map(info_handlers, &build_fn/1)

    quote do
      defmodule unquote(module) do
        import Phoenix.LiveView
        import Phoenix.Component, except: [assign: 2, assign: 3, assign_new: 3]
        import Beacon.Web, only: [assign: 2, assign: 3, assign_new: 3]

        (unquote_splicing(functions))
      end
    end
  end

  defp build_fn(info_handler) do
    %{site: site, msg: msg, code: code} = info_handler
    Beacon.safe_code_check!(site, code)

    quote do
      def handle_info(unquote(Code.string_to_quoted!(msg)), var!(socket)) do
        unquote(Code.string_to_quoted!(code))
      end
    end
  end
end
