defmodule Beacon.Web.API.CacheController do
  @moduledoc false
  use Phoenix.Controller, formats: [:json]

  alias Beacon.GraphQL.ResponseCache
  alias Beacon.PubSub

  require Logger

  @doc """
  DELETE /api/cache/:site/:endpoint_name

  Called by BeaconClient when host app data changes.
  Invalidates the GraphQL response cache and notifies connected LiveViews.
  """
  def invalidate(conn, %{"site" => site_str, "endpoint_name" => endpoint_name}) do
    site = String.to_existing_atom(site_str)

    ResponseCache.invalidate_endpoint(site, endpoint_name)
    PubSub.graphql_cache_invalidated(site, endpoint_name)

    Logger.info("[Beacon.API] Cache invalidated for #{site}/#{endpoint_name}")
    json(conn, %{status: "ok"})
  rescue
    ArgumentError ->
      conn |> put_status(404) |> json(%{error: "site not found"})
  end

  @doc """
  DELETE /api/cache/:site/:endpoint_name/:result_alias

  Granular invalidation for a specific query result.
  """
  def invalidate_query(conn, %{"site" => site_str, "endpoint_name" => endpoint_name, "result_alias" => _result_alias}) do
    site = String.to_existing_atom(site_str)

    ResponseCache.invalidate_endpoint(site, endpoint_name)
    PubSub.graphql_cache_invalidated(site, endpoint_name)

    json(conn, %{status: "ok"})
  rescue
    ArgumentError ->
      conn |> put_status(404) |> json(%{error: "site not found"})
  end
end
