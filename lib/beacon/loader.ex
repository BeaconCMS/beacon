defmodule Beacon.Loader do
  alias Beacon.Loader.Server

  require Logger

  def reload_pages_from_db do
    Server.reload_from_db()
  end

  def page_module_for_site(site) do
    module_for_site(site, "Page")
  end

  def component_module_for_site(site) do
    module_for_site(site, "Component")
  end

  def layout_module_for_site(site) do
    module_for_site(site, "Layout")
  end

  defp module_for_site(site, prefix) do
    site_hash = :crypto.hash(:md5, site) |> Base.encode16()
    Module.concat([BeaconWeb.LiveRenderer, "#{prefix}#{site_hash}"])
  end

  def call_function_with_retry(module, function, args, failure_count \\ 0) do
    try do
      apply(module, function, args)
    rescue
      e in UndefinedFunctionError ->
        cond do
          failure_count >= 10 ->
            Logger.debug("failed 10 times")
            reraise e, __STACKTRACE__

          %UndefinedFunctionError{
            function: ^function,
            module: ^module
          } = e ->
            Logger.debug("failed for the #{failure_count + 1} time, retrying")
            :timer.sleep(100)
            call_function_with_retry(module, function, args, failure_count + 1)

          true ->
            reraise e, __STACKTRACE__
        end
    end
  end
end
