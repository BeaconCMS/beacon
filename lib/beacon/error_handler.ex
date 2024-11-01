defmodule Beacon.ErrorHandler do
  @moduledoc false

  # Beacon custom error handler
  # This module is VERY fragile, any silly mistake will crash the VM.
  # Change with caution.
  # See `https://elixir-lang.org/blog/2012/04/24/a-peek-inside-elixir-s-parallel-compiler/` for more info

  alias Beacon.Loader

  @doc false
  def undefined_function(module, fun, args) do
    ensure_loaded(module) or reload_resource(module)
    :error_handler.undefined_function(module, fun, args)
  end

  @doc false
  def undefined_lambda(module, fun, args) do
    ensure_loaded(module) or reload_resource(module)
    :error_handler.undefined_lambda(module, fun, args)
  end

  def ensure_loaded(module) do
    case :code.ensure_loaded(module) do
      {:module, _} -> true
      {:error, _} -> false
    end
  end

  defp reload_resource(module) when is_atom(module) do
    module
    |> Module.split()
    |> reload_resource()
  end

  defp reload_resource(["Beacon", "Web", "LiveRenderer", _site_id, resource]) do
    reload_beacon_resource(resource)
  end

  defp reload_resource(["Elixir", "Beacon", "Web", "LiveRenderer", _site_id, resource]) do
    reload_beacon_resource(resource)
  end

  defp reload_resource(_module) do
    false
  end

  defp reload_beacon_resource(resource) do
    site = Process.get(:beacon_site)

    case resource do
      "Page" <> page_id -> Loader.reload_page_module(site, page_id)
      "Layout" <> layout_id -> Loader.reload_layout_module(site, layout_id)
      "Routes" -> Loader.reload_routes_module(site)
      "Components" -> Loader.reload_components_module(site)
      "LiveData" -> Loader.reload_live_data_module(site)
      "Stylesheet" -> Loader.reload_stylesheet_module(site)
      "Snippets" -> Loader.reload_snippets_module(site)
      "ErrorPage" -> Loader.reload_error_page_module(site)
      "EventHandlers" -> Loader.reload_event_handlers_module(site)
      "InfoHandlers" -> Loader.reload_info_handlers_module(site)
    end
  end
end
