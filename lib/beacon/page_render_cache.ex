defmodule Beacon.PageRenderCache do
  @moduledoc """
  Hierarchical cache dependency tracker for page renders.

  This module is the single choke point for cache invalidation. It maintains
  reverse dependency mappings so that when a layout, component, or GraphQL endpoint
  changes, all affected pages can be invalidated and their connected LiveViews
  notified.

  ## Dependency Index (ETS keys in `:beacon_runtime_poc`)

    - `{site, :dep, :layout, layout_id}` -> MapSet of page_ids
    - `{site, :dep, :component, component_name}` -> MapSet of page_ids
    - `{site, :dep, :graphql_endpoint, endpoint_name}` -> MapSet of page_ids
    - `{site, :dep, :page_deps, page_id}` -> %{layout_id: id, components: MapSet, graphql_endpoints: MapSet}
  """

  require Logger

  @table :beacon_runtime_poc

  # ---------------------------------------------------------------------------
  # Registration
  # ---------------------------------------------------------------------------

  @doc """
  Registers a page's dependencies in the reverse index.

  The `deps` map should contain:
    - `:layout_id` - the layout ID used by this page
    - `:components` - MapSet of component name atoms used by this page
    - `:graphql_endpoints` - MapSet of GraphQL endpoint names used by this page
  """
  @spec register_page_deps(atom(), String.t(), map()) :: :ok
  def register_page_deps(site, page_id, deps) do
    remove_page_deps(site, page_id)

    layout_id = Map.get(deps, :layout_id)
    components = Map.get(deps, :components, MapSet.new())
    graphql_endpoints = Map.get(deps, :graphql_endpoints, MapSet.new())

    if layout_id do
      add_to_dep_set(site, :layout, layout_id, page_id)
    end

    for component_name <- components do
      add_to_dep_set(site, :component, component_name, page_id)
    end

    for endpoint_name <- graphql_endpoints do
      add_to_dep_set(site, :graphql_endpoint, endpoint_name, page_id)
    end

    :ets.insert(@table, {{site, :dep, :page_deps, page_id}, %{
      layout_id: layout_id,
      components: components,
      graphql_endpoints: graphql_endpoints
    }})

    :ok
  end

  defp remove_page_deps(site, page_id) do
    case :ets.lookup(@table, {site, :dep, :page_deps, page_id}) do
      [{_, old_deps}] ->
        if old_deps.layout_id do
          remove_from_dep_set(site, :layout, old_deps.layout_id, page_id)
        end

        for component_name <- Map.get(old_deps, :components, MapSet.new()) do
          remove_from_dep_set(site, :component, component_name, page_id)
        end

        for endpoint_name <- Map.get(old_deps, :graphql_endpoints, MapSet.new()) do
          remove_from_dep_set(site, :graphql_endpoint, endpoint_name, page_id)
        end

        :ets.delete(@table, {site, :dep, :page_deps, page_id})

      [] ->
        :ok
    end
  end

  defp add_to_dep_set(site, dep_type, dep_key, page_id) do
    ets_key = {site, :dep, dep_type, dep_key}

    current =
      case :ets.lookup(@table, ets_key) do
        [{_, set}] -> set
        [] -> MapSet.new()
      end

    :ets.insert(@table, {ets_key, MapSet.put(current, page_id)})
  end

  defp remove_from_dep_set(site, dep_type, dep_key, page_id) do
    ets_key = {site, :dep, dep_type, dep_key}

    case :ets.lookup(@table, ets_key) do
      [{_, set}] ->
        updated = MapSet.delete(set, page_id)

        if MapSet.size(updated) == 0 do
          :ets.delete(@table, ets_key)
        else
          :ets.insert(@table, {ets_key, updated})
        end

      [] ->
        :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Invalidation
  # ---------------------------------------------------------------------------

  @doc """
  Invalidates a page's render cache entry.
  """
  @spec invalidate_page(atom(), String.t()) :: :ok
  def invalidate_page(site, page_id) do
    :ets.delete(@table, {site, page_id, :render_cache})

    case lookup_page_path(site, page_id) do
      {:ok, path} ->
        Beacon.PubSub.page_render_updated(site, page_id, path)

      :error ->
        :ok
    end

    :ok
  end

  @doc """
  Invalidates all pages that use the given layout.
  """
  @spec invalidate_by_layout(atom(), String.t()) :: :ok
  def invalidate_by_layout(site, layout_id) do
    for {page_id, _path} <- pages_for_layout(site, layout_id) do
      invalidate_page(site, page_id)
    end

    :ok
  end

  @doc """
  Invalidates all pages that use the given component.
  """
  @spec invalidate_by_component(atom(), atom()) :: :ok
  def invalidate_by_component(site, component_name) do
    for {page_id, _path} <- pages_for_component(site, component_name) do
      invalidate_page(site, page_id)
    end

    :ok
  end

  @doc """
  Invalidates all pages that use the given GraphQL endpoint.
  """
  @spec invalidate_by_graphql_endpoint(atom(), binary()) :: :ok
  def invalidate_by_graphql_endpoint(site, endpoint_name) do
    for {page_id, _path} <- pages_for_graphql_endpoint(site, endpoint_name) do
      invalidate_page(site, page_id)
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Page path lookup
  # ---------------------------------------------------------------------------

  @spec pages_for_layout(atom(), String.t()) :: [{String.t(), String.t()}]
  def pages_for_layout(site, layout_id) do
    case :ets.lookup(@table, {site, :dep, :layout, layout_id}) do
      [{_, page_ids}] ->
        Enum.flat_map(page_ids, fn page_id ->
          case lookup_page_path(site, page_id) do
            {:ok, path} -> [{page_id, path}]
            :error -> []
          end
        end)

      [] ->
        []
    end
  end

  @spec pages_for_component(atom(), atom()) :: [{String.t(), String.t()}]
  def pages_for_component(site, component_name) do
    case :ets.lookup(@table, {site, :dep, :component, component_name}) do
      [{_, page_ids}] ->
        Enum.flat_map(page_ids, fn page_id ->
          case lookup_page_path(site, page_id) do
            {:ok, path} -> [{page_id, path}]
            :error -> []
          end
        end)

      [] ->
        []
    end
  end

  @spec pages_for_graphql_endpoint(atom(), binary()) :: [{String.t(), String.t()}]
  def pages_for_graphql_endpoint(site, endpoint_name) do
    case :ets.lookup(@table, {site, :dep, :graphql_endpoint, endpoint_name}) do
      [{_, page_ids}] ->
        Enum.flat_map(page_ids, fn page_id ->
          case lookup_page_path(site, page_id) do
            {:ok, path} -> [{page_id, path}]
            :error -> []
          end
        end)

      [] ->
        []
    end
  end

  defp lookup_page_path(site, page_id) do
    case :ets.lookup(@table, {site, page_id, :manifest}) do
      [{_, manifest}] -> {:ok, manifest.path}
      [] -> :error
    end
  end

  # ---------------------------------------------------------------------------
  # IR component extraction
  # ---------------------------------------------------------------------------

  @doc """
  Extracts component names referenced in an IR tree.
  """
  @spec extract_component_names(term()) :: MapSet.t()
  def extract_component_names(ir) do
    extract_components(ir, MapSet.new())
  end

  defp extract_components(list, acc) when is_list(list) do
    Enum.reduce(list, acc, &extract_components/2)
  end

  defp extract_components({:component, name, _attrs, children}, acc) do
    acc = MapSet.put(acc, name)
    extract_components(children, acc)
  end

  defp extract_components({:tag, _tag, _attrs, children}, acc) do
    extract_components(children, acc)
  end

  defp extract_components({:eex, _expr}, acc), do: acc
  defp extract_components({:eex_block, _expr, children}, acc) do
    extract_components(children, acc)
  end

  defp extract_components({:text, _}, acc), do: acc
  defp extract_components(_, acc), do: acc
end
