defmodule Beacon.ErrorHandler do
  @moduledoc """
  Beacon custom error handler.

  See `https://elixir-lang.org/blog/2012/04/24/a-peek-inside-elixir-s-parallel-compiler/` for more info
  """
  alias Beacon.Loader
  alias Beacon.Loader.Worker
  alias Beacon.Registry

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
    [site_hash, resource_str] =
      "#{module}"
      |> String.split(".")
      |> Enum.slice(-2..-1)

    site = Enum.find(Registry.running_sites(), &(Loader.hash(&1) == site_hash))

    case resource_str do
      "Page" <> page_id -> Worker.reload_page_module(site, page_id)
      other -> :noop
    end
  end
end
