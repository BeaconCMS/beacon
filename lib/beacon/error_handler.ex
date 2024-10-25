defmodule Beacon.ErrorHandler do
  @moduledoc """
  Beacon custom error handler.

  See `https://elixir-lang.org/blog/2012/04/24/a-peek-inside-elixir-s-parallel-compiler/` for more info
  """
  alias Beacon.Loader.Worker

  @doc false
  def undefined_function(module, fun, args) do
    reload_resource(module)
    :error_handler.undefined_function(module, fun, args)
  end

  @doc false
  def undefined_lambda(module, fun, args) do
    reload_resource(module)
    :error_handler.undefined_lambda(module, fun, args)
  end

  defp reload_resource(module) do
    resource_str =
      "#{module}"
      |> String.split(".")
      |> List.last()

    site = Process.get(:beacon_site)

    case resource_str do
      "Page" <> page_id -> Worker.reload_page_module(site, page_id)
      "Layout" <> layout_id -> Worker.reload_layout_module(site, layout_id)
      "Routes" -> Worker.reload_routes_module(site)
      "Components" -> Worker.reload_components_module(site)
      "LiveData" -> Worker.reload_live_data_module(site)
      "Stylesheet" -> Worker.reload_stylesheet_module(site)
      "Snippets" -> Worker.reload_snippets_module(site)
      "ErrorPage" -> Worker.reload_error_page_module(site)
      "EventHandlers" -> Worker.reload_event_handlers_module(site)
      "InfoHandlers" -> Worker.reload_info_handlers_module(site)
      _other -> :noop
    end
  end
end
