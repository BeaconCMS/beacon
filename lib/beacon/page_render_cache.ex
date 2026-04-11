defmodule Beacon.PageRenderCache do
  @moduledoc """
  Hierarchical cache dependency tracker for page renders.

  This module is the single choke point for cache invalidation. It maintains
  reverse dependency mappings so that when a layout, component, or data source
  changes, all affected pages can be invalidated and their connected LiveViews
  notified.

  ## Dependency Index (ETS keys in `:beacon_runtime_poc`)

    - `{site, :dep, :layout, layout_id}` -> MapSet of page_ids
    - `{site, :dep, :component, component_name}` -> MapSet of page_ids
    - `{site, :dep, :data_source, source_name}` -> MapSet of page_ids
    - `{site, :dep, :page_deps, page_id}` -> %{layout_id: id, components: MapSet, data_sources: MapSet}
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
    - `:data_sources` - MapSet of data source name atoms used by this page

  This function:
    1. Removes old dependency entries for this page_id
    2. Adds the page_id to each reverse mapping
    3. Stores the page's dependency set
  """
  @spec register_page_deps(atom(), String.t(), map()) :: :ok
  def register_page_deps(site, page_id, deps) do
    # 1. Remove old dependency entries for this page
    remove_page_deps(site, page_id)

    layout_id = Map.get(deps, :layout_id)
    components = Map.get(deps, :components, MapSet.new())
    data_sources = Map.get(deps, :data_sources, MapSet.new())

    # 2. Add page_id to layout reverse mapping
    if layout_id do
      add_to_dep_set(site, :layout, layout_id, page_id)
    end

    # 3. Add page_id to each component reverse mapping
    for component_name <- components do
      add_to_dep_set(site, :component, component_name, page_id)
    end

    # 4. Add page_id to each data source reverse mapping
    for source_name <- data_sources do
      add_to_dep_set(site, :data_source, source_name, page_id)
    end

    # 5. Store the page's full dependency set
    :ets.insert(@table, {{site, :dep, :page_deps, page_id}, %{
      layout_id: layout_id,
      components: components,
      data_sources: data_sources
    }})

    :ok
  end

  defp remove_page_deps(site, page_id) do
    case :ets.lookup(@table, {site, :dep, :page_deps, page_id}) do
      [{_, old_deps}] ->
        # Remove from layout reverse mapping
        if old_deps.layout_id do
          remove_from_dep_set(site, :layout, old_deps.layout_id, page_id)
        end

        # Remove from component reverse mappings
        for component_name <- Map.get(old_deps, :components, MapSet.new()) do
          remove_from_dep_set(site, :component, component_name, page_id)
        end

        # Remove from data source reverse mappings
        for source_name <- Map.get(old_deps, :data_sources, MapSet.new()) do
          remove_from_dep_set(site, :data_source, source_name, page_id)
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
  # Component Extraction
  # ---------------------------------------------------------------------------

  @doc """
  Walks the IR tree to find all CMS component calls (where module is nil).
  Returns a MapSet of component name atoms.
  """
  @spec extract_component_names(map()) :: MapSet.t()
  def extract_component_names(ir) when is_map(ir) do
    names = walk_ir_for_components(ir, MapSet.new())
    names
  end

  def extract_component_names(_), do: MapSet.new()

  defp walk_ir_for_components(%{dynamics: dynamics} = _ir, acc) when is_list(dynamics) do
    Enum.reduce(dynamics, acc, fn dynamic, inner_acc ->
      walk_dynamic_for_components(dynamic, inner_acc)
    end)
  end

  defp walk_ir_for_components(_, acc), do: acc

  defp walk_dynamic_for_components(%{expr: expr}, acc) do
    walk_expr_for_components(expr, acc)
  end

  defp walk_dynamic_for_components(_, acc), do: acc

  defp walk_expr_for_components({:component_call, {:component_fun, nil, name}, assigns_ir}, acc) when is_atom(name) do
    acc = MapSet.put(acc, name)
    walk_assigns_ir_for_components(assigns_ir, acc)
  end

  defp walk_expr_for_components({:component_call, _fun, assigns_ir}, acc) do
    walk_assigns_ir_for_components(assigns_ir, acc)
  end

  defp walk_expr_for_components({:if, cond_ir, then_ir, else_ir}, acc) do
    acc = walk_expr_for_components(cond_ir, acc)
    acc = walk_expr_for_components(then_ir, acc)
    walk_expr_for_components(else_ir, acc)
  end

  defp walk_expr_for_components({:nested_rendered, inner_ir}, acc) when is_map(inner_ir) do
    walk_ir_for_components(inner_ir, acc)
  end

  defp walk_expr_for_components({:block, exprs}, acc) when is_list(exprs) do
    Enum.reduce(exprs, acc, &walk_expr_for_components/2)
  end

  defp walk_expr_for_components({:for_expr, _var, enum_ir, body_ir}, acc) do
    acc = walk_expr_for_components(enum_ir, acc)
    walk_expr_for_components(body_ir, acc)
  end

  defp walk_expr_for_components({:iodata, inner}, acc) do
    walk_expr_for_components(inner, acc)
  end

  defp walk_expr_for_components({:list, items}, acc) when is_list(items) do
    Enum.reduce(items, acc, &walk_expr_for_components/2)
  end

  defp walk_expr_for_components({:inner_block_ir, inner_ir, _let_var}, acc) when is_map(inner_ir) do
    walk_ir_for_components(inner_ir, acc)
  end

  defp walk_expr_for_components(_, acc), do: acc

  defp walk_assigns_ir_for_components({:component_assigns, pairs}, acc) when is_list(pairs) do
    Enum.reduce(pairs, acc, fn
      {:inner_block, {:literal, slot_irs}}, inner_acc when is_list(slot_irs) ->
        Enum.reduce(slot_irs, inner_acc, fn slot, slot_acc ->
          if is_map(slot) do
            case Map.get(slot, :inner_block) do
              {:inner_block_ir, ir, _let_var} when is_map(ir) ->
                walk_ir_for_components(ir, slot_acc)
              expr ->
                walk_expr_for_components(expr, slot_acc)
            end
          else
            slot_acc
          end
        end)

      {_key, expr}, inner_acc ->
        walk_expr_for_components(expr, inner_acc)
    end)
  end

  defp walk_assigns_ir_for_components(_, acc), do: acc

  # ---------------------------------------------------------------------------
  # Invalidation
  # ---------------------------------------------------------------------------

  @doc """
  Invalidates a single page's cached state and broadcasts an update notification.
  """
  @spec invalidate_page(atom(), String.t()) :: :ok
  def invalidate_page(site, page_id) do
    case lookup_page_path(site, page_id) do
      {:ok, path} ->
        Logger.info("[PageRenderCache] Broadcasting page_render_updated for #{path} (page_id: #{page_id})")
        Beacon.PubSub.page_render_updated(site, page_id, path)

      :error ->
        Logger.warning("[PageRenderCache] No path found for page #{page_id} on site #{site}")
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
  Invalidates all pages that use the given CMS component.
  """
  @spec invalidate_by_component(atom(), atom()) :: :ok
  def invalidate_by_component(site, component_name) do
    for {page_id, _path} <- pages_for_component(site, component_name) do
      invalidate_page(site, page_id)
    end

    :ok
  end

  @doc """
  Invalidates all pages that use the given data source.
  """
  @spec invalidate_by_data_source(atom(), atom()) :: :ok
  def invalidate_by_data_source(site, source_name) do
    for {page_id, _path} <- pages_for_data_source(site, source_name) do
      invalidate_page(site, page_id)
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Page path lookup
  # ---------------------------------------------------------------------------

  @doc """
  Returns list of `{page_id, path}` tuples for all pages using the given layout.
  """
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

  @doc """
  Returns list of `{page_id, path}` tuples for all pages using the given component.
  """
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

  @doc """
  Returns list of `{page_id, path}` tuples for all pages using the given data source.
  """
  @spec pages_for_data_source(atom(), atom()) :: [{String.t(), String.t()}]
  def pages_for_data_source(site, source_name) do
    case :ets.lookup(@table, {site, :dep, :data_source, source_name}) do
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

  # Look up a page's path from its manifest in ETS
  defp lookup_page_path(site, page_id) do
    case :ets.lookup(@table, {site, page_id, :manifest}) do
      [{_, manifest}] -> {:ok, manifest.path}
      [] -> :error
    end
  end
end
