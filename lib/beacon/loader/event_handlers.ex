defmodule Beacon.Loader.EventHandlers do
  @moduledoc false
  alias Beacon.Loader

  def module_name(site), do: Loader.module_name(site, "EventHandlers")

  def build_ast(site, event_handlers) do
    module = module_name(site)
    functions = Enum.map(event_handlers, &build_fn/1)

    quote do
      defmodule unquote(module) do
        import Beacon.Web, only: [assign: 2, assign: 3, assign_new: 3]

        (unquote_splicing(functions))
      end
    end
  end

  defp build_fn(event_handler) do
    %{site: site, name: name, code: code} = event_handler
    Beacon.safe_code_check!(site, code)

    quote do
      def handle_event(unquote(name), var!(event_params), var!(socket)) do
        unquote(Code.string_to_quoted!(code))
      end
    end
  end
end
