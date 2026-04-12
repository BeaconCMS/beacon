defmodule Beacon.Web.API.ASTController do
  @moduledoc false
  use Phoenix.Controller, formats: [:json]

  require Logger

  @doc """
  GET /api/ast/:site/:path

  Returns the page AST, layout AST, CSS URL, and event handlers
  for a given site and path. This is the primary endpoint for
  client SDKs to fetch everything needed to render a page.
  """
  def show(conn, %{"site" => site_str, "path" => path_parts}) do
    site = String.to_existing_atom(site_str)
    path = "/" <> Enum.join(List.wrap(path_parts), "/")

    case fetch_page_ast(site, path) do
      {:ok, response} ->
        json(conn, response)

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "page not found", path: path})

      {:error, reason} ->
        Logger.error("[Beacon.API.AST] Error fetching AST for #{site}#{path}: #{inspect(reason)}")
        conn |> put_status(500) |> json(%{error: "internal error"})
    end
  rescue
    ArgumentError ->
      conn |> put_status(404) |> json(%{error: "site not found"})
  end

  @doc """
  GET /api/ast/:site

  Returns a list of all available page paths for a site.
  Used by clients to discover available pages and pre-fetch ASTs.
  """
  def index(conn, %{"site" => site_str}) do
    site = String.to_existing_atom(site_str)

    pages =
      Beacon.Content.list_published_page_paths(site)
      |> Enum.map(fn {_id, path} -> path end)

    json(conn, %{site: site_str, pages: pages})
  rescue
    ArgumentError ->
      conn |> put_status(404) |> json(%{error: "site not found"})
  end

  defp fetch_page_ast(site, path) do
    table = :beacon_runtime_poc

    # Look up page by path
    case :ets.lookup(table, {site, :route, path}) do
      [{_, page_id}] ->
        page_ast = fetch_ast_from_ets_or_db(site, page_id, table)
        layout_ast = fetch_layout_ast(site, page_id, table)
        manifest = fetch_manifest(site, page_id, table)
        event_handlers = fetch_event_handlers(site, table)
        page_queries = fetch_page_queries(site, page_id)

        response = %{
          page: %{
            ast: page_ast,
            path: manifest[:path] || path,
            title: manifest[:title] || "",
            description: manifest[:description] || "",
            meta_tags: manifest[:meta_tags] || [],
            queries: page_queries
          },
          layout: %{
            ast: layout_ast
          },
          css_url: css_url(site),
          event_handlers: event_handlers
        }

        {:ok, response}

      [] ->
        {:error, :not_found}
    end
  end

  defp fetch_ast_from_ets_or_db(site, page_id, table) do
    # Try ETS first (the page's stored AST from publish)
    case :ets.lookup(table, {site, page_id, :ast}) do
      [{_, ast}] when is_list(ast) or is_map(ast) ->
        ast

      _ ->
        # Fall back to DB
        case Beacon.Content.get_page_ast(site, page_id) do
          nil -> []
          ast -> ast
        end
    end
  end

  defp fetch_layout_ast(site, page_id, table) do
    case :ets.lookup(table, {site, page_id, :manifest}) do
      [{_, manifest}] ->
        layout_id = manifest.layout_id

        case :ets.lookup(table, {site, layout_id, :layout_ast}) do
          [{_, ast}] -> ast
          _ -> []
        end

      _ ->
        []
    end
  end

  defp fetch_manifest(site, page_id, table) do
    case :ets.lookup(table, {site, page_id, :manifest}) do
      [{_, manifest}] -> manifest
      _ -> %{}
    end
  end

  defp fetch_event_handlers(site, table) do
    case :ets.lookup(table, {site, :site_handler_index, :event}) do
      [{_, names}] ->
        Map.new(names, fn name ->
          case :ets.lookup(table, {site, :site_handler, :event, name}) do
            [{_, {:actions, action_doc}}] -> {name, action_doc}
            _ -> {name, nil}
          end
        end)
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()

      _ ->
        %{}
    end
  end

  defp fetch_page_queries(site, page_id) do
    Beacon.Content.list_page_queries(site, page_id)
    |> Enum.map(fn q ->
      %{
        endpoint_name: q.endpoint_name,
        query_string: q.query_string,
        variable_bindings: q.variable_bindings,
        result_alias: q.result_alias,
        depends_on: q.depends_on
      }
    end)
  end

  defp css_url(site) do
    "/__beacon_assets__/css-#{site}"
  end
end
