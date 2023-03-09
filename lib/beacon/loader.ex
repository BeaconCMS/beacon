defmodule Beacon.Loader do
  alias Beacon.Loader.Server

  require Logger

  defmodule Error do
    # Using `plug_status` for rendering this exception as 404 in production.
    # More info: https://hexdocs.pm/phoenix/custom_error_pages.html#custom-exceptions
    defexception message: "Error in Beacon.Loader", plug_status: 404
  end

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

  def stylesheet_module_for_site(site) do
    module_for_site(site, "Stylesheet")
  end

  defp module_for_site(site, prefix) do
    site_hash = :crypto.hash(:md5, Atom.to_string(site)) |> Base.encode16()
    Module.concat([BeaconWeb.LiveRenderer, "#{prefix}#{site_hash}"])
  end

  @doc """
  This retry logic exists because a module may be in the process of being reloaded, in which case we want to retry
  """
  def call_function_with_retry(module, function, args, failure_count \\ 0) do
    apply(module, function, args)
  rescue
    e in UndefinedFunctionError ->
      case {failure_count, e} do
        {x, _} when x >= 10 ->
          Logger.debug("Failed to call #{inspect(module)} #{inspect(function)} 10 times.")
          reraise e, __STACKTRACE__

        {_, %UndefinedFunctionError{function: ^function, module: ^module}} ->
          Logger.debug("Failed to call #{inspect(module)} #{inspect(function)} with #{inspect(args)} for the #{failure_count + 1} time. Retrying.")
          :timer.sleep(100 * (failure_count * 2))

          call_function_with_retry(module, function, args, failure_count + 1)

        _ ->
          reraise e, __STACKTRACE__
      end

    _e in FunctionClauseError ->
      error_message = """
      Could not call #{function} for the given path: #{inspect(List.flatten(args))}.

      Make sure you have created a page for this path. Check Pages.create_page!/2 \
      for more info.\
      """

      reraise __MODULE__.Error, [message: error_message], __STACKTRACE__

    e ->
      reraise e, __STACKTRACE__
  end
end
