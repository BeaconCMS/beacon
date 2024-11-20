defmodule Beacon.ErrorHandler do
  @moduledoc false

  # Beacon custom error handler to autoload modules at runtime.
  # This module is fragile, any silly mistake will crash the VM without logs. Change with caution.
  # See https://elixir-lang.org/blog/2012/04/24/a-peek-inside-elixir-s-parallel-compiler for more info
  #
  # Note that we don't raise in this module because it must propagate the error upstream,
  # so for example a UndefinedFunctionError can be captured by Beacon and re-raised as
  # a more meaningful error message with a proper Plug status.

  alias Beacon.Loader

  require Logger

  def undefined_function(module, fun, args) do
    ensure_loaded(module) or load_resource(module)
    :error_handler.undefined_function(module, fun, args)
  end

  def undefined_lambda(module, fun, args) do
    ensure_loaded(module) or load_resource(module)
    :error_handler.undefined_lambda(module, fun, args)
  end

  def enable(site) do
    Process.put(:__beacon_site__, site)
    Process.flag(:error_handler, Beacon.ErrorHandler)
  end

  defp ensure_loaded(module) do
    case :code.ensure_loaded(module) do
      {:module, _} -> true
      {:error, _} -> false
    end
  end

  defp load_resource(module) when is_atom(module) do
    module
    |> Module.split()
    |> load_resource()
  rescue
    # ignore erlang modules
    _ -> false
  end

  defp load_resource(["Beacon", "Web", "LiveRenderer", _site_id, resource]) do
    load_beacon_resource(Process.get(:__beacon_site__), resource)
  end

  defp load_resource(_module), do: false

  defp load_beacon_resource(nil = _site, _resource), do: false

  defp load_beacon_resource(site, resource) do
    # TODO eventually replace Logger with Beacon telemetry
    Logger.debug("#{__MODULE__} loading #{resource} for #{site}")

    case resource do
      "Page" <> page_id -> Loader.load_page_module(site, page_id)
      "Layout" <> layout_id -> Loader.load_layout_module(site, layout_id)
      "Routes" -> Loader.load_routes_module(site)
      "Components" -> Loader.load_components_module(site)
      "LiveData" -> Loader.load_live_data_module(site)
      "Stylesheet" -> Loader.load_stylesheet_module(site)
      "Snippets" -> Loader.load_snippets_module(site)
      "ErrorPage" -> Loader.load_error_page_module(site)
      "EventHandlers" -> Loader.load_event_handlers_module(site)
      "InfoHandlers" -> Loader.load_info_handlers_module(site)
      _ -> false
    end
  end
end
