defmodule Beacon.Igniter do
  @moduledoc false

  def select_router!(igniter, opts \\ []) do
    label = Keyword.get(opts, :label)
    raise_msg = Keyword.get(opts, :raise_msg, "No router found.")

    case Igniter.Libs.Phoenix.select_router(igniter, label) do
      {_igniter, nil} -> Mix.raise(raise_msg)
      found -> found
    end
  end

  def select_endpoint(igniter, router, label \\ "Which endpoint should be modified?") do
    case Igniter.Libs.Phoenix.endpoints_for_router(igniter, router) do
      {igniter, []} ->
        {igniter, nil}

      {igniter, [endpoint]} ->
        {igniter, endpoint}

      {igniter, endpoints} ->
        {igniter, Igniter.Util.IO.select(label, endpoints, display: &inspect/1)}
    end
  end

  def select_endpoint!(igniter, router, opts \\ []) do
    label = Keyword.get(opts, :label)
    raise_msg = Keyword.get(opts, :raise_msg, "No endpoint found.")

    case select_endpoint(igniter, router, label) do
      {_igniter, nil} -> Mix.raise(raise_msg)
      found -> found
    end
  end
end
