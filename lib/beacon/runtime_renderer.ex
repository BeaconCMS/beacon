defmodule Beacon.RuntimeRenderer do
  require Logger

  @moduledoc """
  Proof of concept: Runtime page rendering without ANY runtime code compilation.

  At publish time, HEEx templates are compiled through Phoenix's standard pipeline,
  then the resulting AST is transformed into a serializable intermediate representation
  (IR). The IR captures the static HTML parts, fingerprint, and dynamic expression
  descriptors as plain data.

  At request time, a single precompiled evaluator walks the IR and constructs
  `%Phoenix.LiveView.Rendered{}` structs. The closures in the `dynamic` field
  reference THIS module (compiled once at app build time) — not any per-page module.

  Zero `Code.eval_quoted`. Zero `Code.eval_string`. Zero runtime module creation.
  """

  @table :beacon_runtime_poc

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  def init do
    # Table is created by Beacon.Application.start to ensure it outlives Boot.
    # This is a no-op safety check for test environments.
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:set, :named_table, :public, read_concurrency: true])
    end

    Beacon.CircuitBreaker.init()

    :ok
  end

  # ---------------------------------------------------------------------------
  # Publish time — compile template to IR, store everything in ETS
  # ---------------------------------------------------------------------------

  def publish_page(site, page_id, attrs) when is_atom(site) and is_binary(page_id) do
    template = Map.fetch!(attrs, :template)
    path = Map.get(attrs, :path, "/")

    # 1. Compile HEEx to AST via standard Phoenix pipeline
    env = Beacon.Web.PageLive.make_env(site)
    {:ok, ast} = Beacon.Template.HEEx.compile(site, path, template)

    # 2. Transform AST into serializable IR (no closures, no module refs)
    ir = extract_ir(ast, env)
    :ets.insert(@table, {{site, page_id, :ir}, :erlang.term_to_binary(ir)})

    # 3. Store the page manifest — everything needed to mount and render
    manifest = %{
      id: page_id,
      site: site,
      path: path,
      title: Map.get(attrs, :title, ""),
      description: Map.get(attrs, :description, ""),
      format: Map.get(attrs, :format, :heex),
      layout_id: Map.get(attrs, :layout_id),
      extra: Map.get(attrs, :extra, %{}),
      meta_tags: Map.get(attrs, :meta_tags, []),
      raw_schema: Map.get(attrs, :raw_schema, [])
    }

    :ets.insert(@table, {{site, page_id, :manifest}, manifest})

    # 4. Register route: path → page_id (for mount-time lookup)
    :ets.insert(@table, {{site, :route, path}, page_id})

    # 5. Store custom page assigns (live_data, user-defined)
    static_assigns = Map.get(attrs, :assigns, %{})
    :ets.insert(@table, {{site, page_id, :assigns}, static_assigns})

    # 6. Store live_data definitions (evaluated at handle_params time)
    live_data_defs = Map.get(attrs, :live_data, [])
    :ets.insert(@table, {{site, page_id, :live_data}, live_data_defs})

    # 7. Store event handlers — parse to AST at publish time, not runtime
    handlers = Map.get(attrs, :event_handlers, [])

    for %{name: name, code: code} <- handlers do
      handler_ast = Code.string_to_quoted!(code)
      :ets.insert(@table, {{site, page_id, :handler, name}, :erlang.term_to_binary(handler_ast)})
    end

    handler_names = Enum.map(handlers, & &1.name)
    :ets.insert(@table, {{site, page_id, :handler_index}, handler_names})

    # 8. Store page helpers (dynamic_helper calls)
    helpers = Map.get(attrs, :helpers, [])

    for helper <- helpers do
      helper_ast = Code.string_to_quoted!(helper.code)
      args_ast = Code.string_to_quoted!(helper.args)
      :ets.insert(@table, {{site, page_id, :helper, helper.name}, :erlang.term_to_binary(%{code: helper_ast, args: args_ast})})
    end

    # 9. Extract CSS candidates and track for conditional recompilation
    candidates = Beacon.CSS.CandidateExtractor.extract(template)
    :ets.insert(@table, {{site, page_id, :css_candidates}, candidates})

    known =
      case :ets.lookup(@table, {site, :css_candidates}) do
        [{_, existing}] -> existing
        [] -> MapSet.new()
      end

    new_classes = MapSet.difference(candidates, known)

    if MapSet.size(new_classes) > 0 do
      updated = MapSet.union(known, new_classes)
      :ets.insert(@table, {{site, :css_candidates}, updated})
    end

    # 10. Register page dependencies for cascade invalidation
    component_names = Beacon.PageRenderCache.extract_component_names(ir)

    data_source_names =
      manifest.extra
      |> Map.get("data_sources", [])
      |> Enum.map(fn spec -> spec["source"] || spec[:source] end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&safe_to_existing_atom/1)
      |> MapSet.new()

    Beacon.PageRenderCache.register_page_deps(site, page_id, %{
      layout_id: manifest.layout_id,
      components: component_names,
      data_sources: data_source_names
    })

    :ok
  end

  # ---------------------------------------------------------------------------
  # Layout publishing and rendering
  # ---------------------------------------------------------------------------

  @doc """
  Publishes a layout into the ETS store. Called during site boot.
  """
  def publish_layout(site, layout_id, template, opts \\ []) when is_atom(site) and is_binary(layout_id) do
    path = "layout_#{layout_id}"
    env = Beacon.Web.PageLive.make_env(site)
    {:ok, ast} = Beacon.Template.HEEx.compile(site, path, template)
    ir = extract_ir(ast, env)
    :ets.insert(@table, {{site, :layout, layout_id}, :erlang.term_to_binary(ir)})

    # Store layout metadata (meta_tags, resource_links) separately
    manifest = %{
      id: layout_id,
      meta_tags: Keyword.get(opts, :meta_tags, []),
      resource_links: Keyword.get(opts, :resource_links, [])
    }

    :ets.insert(@table, {{site, :layout, layout_id, :manifest}, manifest})

    :ok
  end

  @doc """
  Fetches layout metadata (meta_tags, resource_links) from ETS.
  """
  def fetch_layout_manifest(site, layout_id) do
    case :ets.lookup(@table, {site, :layout, layout_id, :manifest}) do
      [{_, manifest}] -> {:ok, manifest}
      [] -> :error
    end
  end

  @doc """
  Renders a layout by layout_id. Returns `{:ok, rendered}` or `{:error, :not_found}`.
  """
  def render_layout(site, layout_id, assigns) do
    case :ets.lookup(@table, {site, :layout, layout_id}) do
      [{_, serialized_ir}] ->
        ir = :erlang.binary_to_term(serialized_ir)
        # Delete __changed__ so all dynamic expressions evaluate on first render.
        # The layout references page-level assigns (like :post) that aren't in __changed__,
        # which would cause them to be skipped by change tracking.
        full_assigns = Map.delete(assigns, :__changed__)
        {:ok, render_ir(ir, full_assigns)}

      [] ->
        ttl = Beacon.Config.effective_ttl(Beacon.Config.fetch!(site), :layouts)

        Beacon.Cache.fetch(@table, {site, :layout_load, layout_id}, fn ->
          case Beacon.Content.get_published_layout(site, layout_id) do
            nil ->
              :not_found

            layout ->
              publish_layout(site, to_string(layout.id), layout.template,
                meta_tags: layout.meta_tags || [],
                resource_links: layout.resource_links || []
              )
          end
        end, ttl)

        case :ets.lookup(@table, {site, :layout, layout_id}) do
          [{_, serialized_ir}] ->
            ir = :erlang.binary_to_term(serialized_ir)
            full_assigns = Map.delete(assigns, :__changed__)
            {:ok, render_ir(ir, full_assigns)}

          [] ->
            {:error, :not_found}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Error page publishing and rendering
  # ---------------------------------------------------------------------------

  @doc """
  Publishes an error page into the ETS store. Called during site boot.
  Compiles the HEEx template to IR and stores it keyed by status code.
  """
  def publish_error_page(site, status_code, template) when is_atom(site) and is_integer(status_code) do
    path = "error_page_#{status_code}"
    env = Beacon.Web.PageLive.make_env(site)
    {:ok, ast} = Beacon.Template.HEEx.compile(site, path, template)
    ir = extract_ir(ast, env)
    :ets.insert(@table, {{site, :error_page, status_code}, :erlang.term_to_binary(ir)})

    :ok
  end

  @doc """
  Renders an error page by status code. Returns `{:ok, rendered}` or `{:error, :not_found}`.
  Uses a lazy-load fallback pattern matching render_layout.
  """
  def render_error_page(site, status_code, assigns) do
    case :ets.lookup(@table, {site, :error_page, status_code}) do
      [{_, serialized_ir}] ->
        ir = :erlang.binary_to_term(serialized_ir)
        full_assigns = Map.delete(assigns, :__changed__)
        {:ok, render_ir(ir, full_assigns)}

      [] ->
        ttl = Beacon.Config.effective_ttl(Beacon.Config.fetch!(site), :error_pages)

        Beacon.Cache.fetch(@table, {site, :error_page_load, status_code}, fn ->
          case Beacon.Content.list_error_pages(site, per_page: :infinity) do
            error_pages when is_list(error_pages) ->
              Enum.find(error_pages, &(&1.status == status_code))
              |> case do
                nil -> :not_found
                error_page -> publish_error_page(site, error_page.status, error_page.template)
              end

            _ ->
              :not_found
          end
        end, ttl)

        case :ets.lookup(@table, {site, :error_page, status_code}) do
          [{_, serialized_ir}] ->
            ir = :erlang.binary_to_term(serialized_ir)
            full_assigns = Map.delete(assigns, :__changed__)
            {:ok, render_ir(ir, full_assigns)}

          [] ->
            {:error, :not_found}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Component publishing and rendering
  # ---------------------------------------------------------------------------

  @doc """
  Publishes a component into the ETS store. Called during site boot.
  """
  def publish_component(site, name, template, body \\ "", opts \\ []) when is_atom(site) and is_binary(name) do
    path = "component_#{name}"
    env = Beacon.Web.PageLive.make_env(site)
    {:ok, ast} = Beacon.Template.HEEx.compile(site, path, template)
    ir = extract_ir(ast, env)

    # Extract default attr values from component attrs
    attrs = Keyword.get(opts, :attrs, [])
    defaults =
      Enum.reduce(attrs, %{}, fn
        %{name: attr_name, opts: attr_opts}, acc ->
          case Keyword.get(attr_opts || [], :default) do
            nil -> acc
            default -> Map.put(acc, String.to_existing_atom(attr_name), default)
          end
        _, acc -> acc
      end)

    :ets.insert(@table, {{site, :component, name}, :erlang.term_to_binary(%{ir: ir, body: body, defaults: defaults})})

    :ok
  end

  @doc """
  Renders a component by name with the given assigns.
  Returns the rendered output or an empty string if not found.
  """
  def render_component(site, name, assigns) when is_atom(site) and is_binary(name) do
    do_render_component(site, name, assigns)
  rescue
    error ->
      require Logger
      Logger.error("[RuntimeRenderer] Component #{name} crashed: #{Exception.message(error)}\n#{Exception.format_stacktrace(__STACKTRACE__)}")
      ""
  end

  defp do_render_component(site, name, assigns) do
    case :ets.lookup(@table, {site, :component, name}) do
      [{_, serialized}] ->
        data = :erlang.binary_to_term(serialized)
        %{ir: ir, body: body} = data
        defaults = Map.get(data, :defaults, %{})

        # Apply default attr values for missing assigns
        assigns = Map.merge(defaults, assigns)

        # Execute the component body to produce local bindings
        body_bindings = execute_component_body(body, assigns)

        full_assigns =
          assigns
          |> Map.merge(body_bindings)
          |> Map.delete(:__changed__)
          |> Map.put_new(:inner_block, [])
          |> Map.put_new(:beacon, %{site: site})

        render_ir_with_bindings(ir, full_assigns, body_bindings)

      [] ->
        ttl = Beacon.Config.effective_ttl(Beacon.Config.fetch!(site), :components)

        Beacon.Cache.fetch(@table, {site, :component_load, name}, fn ->
          case Beacon.Content.get_component_by(site, [name: name], preloads: [:attrs]) do
            nil ->
              :not_found

            component ->
              component_attrs = (component.attrs || [])
              attrs_list = Enum.map(component_attrs, fn a -> %{name: a.name, opts: a.opts || []} end)
              publish_component(site, component.name, component.template, component.body || "", attrs: attrs_list)
          end
        end, ttl)

        # Re-check after load
        case :ets.lookup(@table, {site, :component, name}) do
          [{_, serialized}] ->
            data = :erlang.binary_to_term(serialized)
            %{ir: ir, body: body} = data
            defaults = Map.get(data, :defaults, %{})
            assigns = Map.merge(defaults, assigns)
            body_bindings = execute_component_body(body, assigns)

            full_assigns =
              assigns
              |> Map.merge(body_bindings)
              |> Map.delete(:__changed__)
              |> Map.put_new(:inner_block, [])
              |> Map.put_new(:beacon, %{site: site})

            render_ir_with_bindings(ir, full_assigns, body_bindings)

          [] ->
            require Logger
            Logger.warning("[RuntimeRenderer] Component #{name} not found for site #{site}")
            ""
        end
    end
  end

  @doc false
  def render_ir_with_bindings(ir, assigns, bindings) do
    %Phoenix.LiveView.Rendered{
      static: ir.static,
      dynamic: &evaluate_dynamics_with_bindings(ir.dynamics, assigns, bindings, &1),
      fingerprint: ir.fingerprint,
      root: Map.get(ir, :root, false),
      caller: :not_available
    }
  end

  defp evaluate_dynamics_with_bindings(dynamics, assigns, bindings, track_changes?) do
    changed = if track_changes?, do: Map.get(assigns, :__changed__), else: nil

    {results, _bindings} =
      Enum.reduce(dynamics, {[], bindings}, fn %{deps: deps, expr: expr}, {acc, b} ->
        case expr do
          {:bind, name, value_expr} ->
            value = eval_ir(value_expr, assigns, b)
            {acc, Map.put(b, name, value)}

          _ ->
            if changed != nil and deps != [] and not Enum.any?(deps, &Map.has_key?(changed, &1)) do
              {[nil | acc], b}
            else
              result = eval_ir(expr, assigns, b)
              {[safe_dynamic(result) | acc], b}
            end
        end
      end)

    Enum.reverse(results)
  end

  defp execute_component_body(nil, _assigns), do: %{}
  defp execute_component_body("", _assigns), do: %{}

  defp execute_component_body(body, assigns) when is_binary(body) do
    ast = Code.string_to_quoted!(body)
    # Body code uses `assigns` as a variable — bind it to the component's assigns
    bindings_with_assigns = Map.put(assigns, :assigns, assigns)
    {_result, bindings} = eval_body_ast(ast, bindings_with_assigns)

    # If the body reassigned `assigns`, use the new assigns map as the bindings
    # so that the template sees the updated values.
    # Common pattern: `assigns = Map.put(assigns, :key, value)`
    case Map.get(bindings, :assigns) do
      %{} = new_assigns ->
        other_bindings = Map.drop(bindings, [:assigns])
        Map.merge(new_assigns, other_bindings)

      _ ->
        bindings
    end
  rescue
    error ->
      require Logger
      Logger.error("[RuntimeRenderer] Component body execution failed: #{Exception.message(error)}\n#{Exception.format_stacktrace(__STACKTRACE__)}")
      %{}
  end

  # Evaluate body AST and collect variable bindings
  defp eval_body_ast({:__block__, _, exprs}, assigns) do
    Enum.reduce(exprs, {nil, %{}}, fn expr, {_result, bindings} ->
      {val, new_bindings} = eval_body_ast(expr, Map.merge(assigns, bindings))
      {val, Map.merge(bindings, new_bindings)}
    end)
  end

  defp eval_body_ast({:=, _, [{name, _, nil}, value_ast]}, assigns) when is_atom(name) do
    value = eval_ast(value_ast, assigns)
    {value, %{name => value}}
  end

  defp eval_body_ast(other, assigns) do
    {eval_ast(other, assigns), %{}}
  end

  # ---------------------------------------------------------------------------
  # Snippet helpers — evaluate snippet helper bodies (replaces compiled Snippets module)
  # ---------------------------------------------------------------------------

  @doc """
  Stores a snippet helper's body in ETS, keyed by site and helper name.
  Called during site boot to pre-load all snippet helpers.
  """
  def publish_snippet_helper(site, helper_name, body) when is_atom(site) and is_binary(helper_name) do
    :ets.insert(@table, {{site, :snippet_helper, helper_name}, body})
    :ok
  end

  @doc """
  Renders a snippet helper by name. Evaluates the helper's body code with
  the given assigns using the AST interpreter.

  The snippet helper body is Elixir code that receives `assigns` as a map
  (e.g., `assigns["page"]`). Returns the result as a string.

  Returns `{:ok, result}` or `{:error, :not_found}`.
  """
  def render_snippet_helper(site, helper_name, assigns) when is_atom(site) do
    case :ets.lookup(@table, {site, :snippet_helper, helper_name}) do
      [{_, body}] ->
        result = eval_snippet_helper_body(body, assigns)
        {:ok, result}

      [] ->
        # Lazy-load snippet helpers for this site
        ttl = Beacon.Config.effective_ttl(Beacon.Config.fetch!(site), :snippets)

        Beacon.Cache.fetch(@table, {site, :snippet_helpers_load}, fn ->
          helpers = Beacon.Content.list_snippet_helpers(site)

          for helper <- helpers do
            publish_snippet_helper(site, helper.name, helper.body)
          end

          :loaded
        end, ttl)

        case :ets.lookup(@table, {site, :snippet_helper, helper_name}) do
          [{_, body}] ->
            result = eval_snippet_helper_body(body, assigns)
            {:ok, result}

          [] ->
            {:error, :not_found}
        end
    end
  end

  defp eval_snippet_helper_body(body, assigns) when is_binary(body) do
    ast = Code.string_to_quoted!(body)
    bindings = %{assigns: assigns}
    eval_ast(ast, bindings)
  rescue
    error ->
      require Logger
      Logger.warning("[RuntimeRenderer] Snippet helper evaluation failed: #{Exception.message(error)}")
      ""
  end

  # ---------------------------------------------------------------------------
  # Route lookup — resolve path to page_id (replaces RouterServer)
  # ---------------------------------------------------------------------------

  @doc """
  Looks up a page_id by site and path. Used at mount time.
  Returns `{:ok, page_id}` or `:error`.
  """
  def lookup_page(site, path) when is_atom(site) and is_binary(path) do
    # Fast path: exact match in ETS
    case :ets.lookup(@table, {site, :route, path}) do
      [{_, page_id}] ->
        {:ok, page_id}

      [] ->
        # Check dynamic segments against cached routes (populated at boot)
        case match_dynamic_route(site, path) do
          {:ok, page_id} ->
            # Route found but page IR may not be loaded yet (lazy loading).
            # Ensure the page is loaded before returning.
            ensure_page_loaded(site, page_id)
            {:ok, page_id}

          :error ->
            load_page_by_path(site, path)
        end
    end
  end

  defp match_dynamic_route(site, path) do
    request_segments = String.split(path, "/", trim: true)
    all_routes = :ets.match(@table, {{site, :route, :"$1"}, :"$2"})

    Enum.find_value(all_routes, :error, fn [route_path, page_id] ->
      route_segments = String.split(route_path, "/", trim: true)

      if length(route_segments) == length(request_segments) do
        matches? =
          Enum.zip(route_segments, request_segments)
          |> Enum.all?(fn
            {":" <> _, _} -> true
            {"*" <> _, _} -> true
            {a, b} -> a == b
          end)

        if matches?, do: {:ok, page_id}, else: nil
      end
    end)
  end

  defp load_page_by_path(site, path) do
    config = Beacon.Config.fetch!(site)

    # If the page was previously loaded, use its per-page TTL from the manifest.
    # On first load, fall back to the site-wide :pages TTL.
    ttl =
      with [{_, page_id}] <- :ets.lookup(@table, {site, :route, path}),
           {:ok, manifest} <- fetch_manifest(site, page_id) do
        Beacon.Config.effective_ttl(config, :pages, manifest.extra)
      else
        _ -> Beacon.Config.effective_ttl(config, :pages)
      end

    Beacon.Cache.fetch(@table, {site, :page_load, path}, fn ->
      wait_for_load_slot(site)

      try do
        case Beacon.Content.list_published_pages_for_paths(site, [path]) do
          [page] ->
            Beacon.RuntimeRenderer.Loader.load_page(site, page)
            {:ok, page.id}

          _ ->
            # No exact match — try matching against dynamic route patterns in the DB
            match_dynamic_route_from_db(site, path)
        end
      after
        release_load_slot(site)
      end
    end, ttl)
  end

  defp match_dynamic_route_from_db(site, path) do
    request_segments = String.split(path, "/", trim: true)

    # Query only paths (lightweight) to find a dynamic route pattern that matches
    Beacon.Content.list_published_page_paths(site)
    |> Enum.find_value(:error, fn {_page_id, route_path} ->
      route_segments = String.split(route_path, "/", trim: true)

      if length(route_segments) == length(request_segments) do
        matches? =
          Enum.zip(route_segments, request_segments)
          |> Enum.all?(fn
            {":" <> _, _} -> true
            {"*" <> _, _} -> true
            {a, b} -> a == b
          end)

        if matches? do
          # Found a matching dynamic route — load the page by its pattern path
          case Beacon.Content.list_published_pages_for_paths(site, [route_path]) do
            [page] ->
              Beacon.RuntimeRenderer.Loader.load_page(site, page)
              {:ok, page.id}

            _ ->
              nil
          end
        end
      end
    end)
  end

  @doc """
  Clears cached live_data definitions for all pages on a site.
  Pages will lazy-load fresh definitions from the DB on next request.
  """
  def clear_live_data_cache(site) do
    :ets.match_delete(@table, {{site, :"$1", :live_data}, :_})
  end

  @doc """
  Registers a route (path → page_id) in ETS without loading the page IR.
  Used at boot to populate the route index for dynamic route matching.
  """
  def register_route(site, page_id, path) do
    :ets.insert(@table, {{site, :route, path}, page_id})
  end

  @max_concurrent_page_loads 4

  @doc false
  def ensure_page_loaded(site, page_id) do
    # Check if the page IR is already in ETS
    case :ets.lookup(@table, {site, page_id, :ir}) do
      [{_, _}] ->
        :ok

      [] ->
        # Page route is known but IR not loaded yet — load from DB
        case fetch_manifest(site, page_id) do
          {:ok, _} ->
            :ok

          :error ->
            # No manifest either — need to load the full page from DB.
            # Throttle concurrent loads to prevent thundering herd when
            # a bot crawls many pages simultaneously on a cold cache.
            throttled_page_load(site, page_id)
        end
    end
  end

  defp throttled_page_load(site, page_id) do
    config = Beacon.Config.fetch!(site)
    ttl = Beacon.Config.effective_ttl(config, :pages)

    Beacon.Cache.fetch(@table, {site, :page_load, page_id}, fn ->
      wait_for_load_slot(site)

      try do
        case Beacon.Content.get_published_page(site, page_id) do
          nil -> :error
          page -> Beacon.RuntimeRenderer.Loader.load_page(site, page); :ok
        end
      after
        release_load_slot(site)
      end
    end, ttl)
  end

  defp wait_for_load_slot(site) do
    key = {site, :page_load_count}

    case :ets.update_counter(@table, key, {2, 1}, {key, 0}) do
      count when count <= @max_concurrent_page_loads ->
        :ok

      _ ->
        # Over limit — back off and retry
        :ets.update_counter(@table, key, {2, -1})
        Process.sleep(50 + :rand.uniform(100))
        wait_for_load_slot(site)
    end
  end

  defp release_load_slot(site) do
    :ets.update_counter(@table, {site, :page_load_count}, {2, -1})
  end

  def lookup_page!(site, path) do
    case lookup_page(site, path) do
      {:ok, page_id} ->
        page_id

      :error ->
        # Debug: list all stored routes for this site
        all_routes = :ets.match(@table, {{site, :route, :"$1"}, :"$2"})
        sample = all_routes |> Enum.take(10) |> Enum.map(fn [p, _id] -> p end)
        require Logger
        Logger.error("[RuntimeRenderer] Route lookup failed for path=#{inspect(path)}, site=#{site}. Sample routes: #{inspect(sample)}")
        raise "no page found for site #{site} path #{path}"
    end
  end

  # ---------------------------------------------------------------------------
  # Route listing — scan ETS for all routes
  # ---------------------------------------------------------------------------

  @doc """
  Lists all routes for a site. Scans ETS for all `{site, :route, path}` entries
  and returns a list of `%{path: path, page_id: page_id}`.
  """
  def list_routes(site) when is_atom(site) do
    :ets.match(@table, {{site, :route, :"$1"}, :"$2"})
    |> Enum.map(fn [path, page_id] -> %{path: path, page_id: page_id} end)
  end

  # ---------------------------------------------------------------------------
  # Route helpers — URL generation without compiled modules
  # ---------------------------------------------------------------------------

  @doc """
  Returns the full public URL for a page.
  """
  def public_page_url(site, page) do
    config = Beacon.Config.fetch!(site)
    prefix = config.router.__beacon_scoped_prefix_for_site__(site)
    path = sanitize_path("#{prefix}#{page.path}")
    uri = Beacon.ProxyEndpoint.public_uri(site)
    String.Chars.URI.to_string(%{uri | path: path})
  end

  @doc """
  Returns the public site URL (scheme + host + port + prefix, no trailing slash).
  """
  def public_site_url(site) do
    uri =
      case Beacon.ProxyEndpoint.public_uri(site) do
        %{path: "/"} = uri -> %{uri | path: nil}
        uri -> uri
      end

    String.Chars.URI.to_string(uri)
  end

  @doc """
  Returns the public sitemap URL for a site.
  """
  def public_sitemap_url(site) do
    public_site_url(site) <> "/sitemap.xml"
  end

  @doc """
  Returns the media asset path for a file.
  """
  def beacon_media_path(site, file_name) do
    config = Beacon.Config.fetch!(site)
    prefix = config.router.__beacon_scoped_prefix_for_site__(site)
    sanitize_path("#{prefix}/__beacon_media__/#{file_name}")
  end

  @doc """
  Returns the full media asset URL for a file.
  """
  def beacon_media_url(site, file_name) do
    uri = Beacon.ProxyEndpoint.public_uri(site)
    host = String.Chars.URI.to_string(%URI{scheme: uri.scheme, host: uri.host, port: uri.port})
    host <> beacon_media_path(site, file_name)
  end

  defp sanitize_path(path), do: String.replace(path, "//", "/")

  # ---------------------------------------------------------------------------
  # Page manifest — all metadata needed to mount (replaces page_module.page())
  # ---------------------------------------------------------------------------

  @doc """
  Fetches the page manifest. Contains all metadata the LiveView needs at
  mount time: id, site, path, title, layout_id, meta_tags, etc.

  No compiled module is touched.
  """
  def fetch_manifest(site, page_id) do
    case :ets.lookup(@table, {site, page_id, :manifest}) do
      [{_, manifest}] -> {:ok, manifest}
      [] -> :error
    end
  end

  def fetch_manifest!(site, page_id) do
    case fetch_manifest(site, page_id) do
      {:ok, manifest} -> manifest
      :error -> raise "no manifest for site #{site} page #{page_id}"
    end
  end

  # ---------------------------------------------------------------------------
  # Mount — produces initial socket assigns (replaces PageLive.mount logic)
  # ---------------------------------------------------------------------------

  @doc """
  Produces the assigns map for a LiveView mount given a site and path.

  This replaces the current flow of:
    RouterServer.lookup_page! → page_module.page() → BeaconAssigns.new(page)

  Returns `{:ok, assigns_map}` where assigns_map contains:
  - `:beacon` — the beacon assigns struct equivalent (as a plain map)
  - `:page_title` — the page title

  No compiled modules are loaded or referenced.
  """
  def mount_assigns(site, path, opts \\ []) when is_atom(site) and is_binary(path) do
    case Beacon.CircuitBreaker.check(site, path) do
      {:tripped, _remaining} -> raise Beacon.Web.ServerError, "page is temporarily unavailable"
      :ok -> :ok
    end

    try do
      do_mount_assigns(site, path, opts)
    rescue
      error ->
        unless client_error?(error) do
          ttl = Beacon.Config.fetch!(site).circuit_breaker_ttl
          if ttl > 0, do: Beacon.CircuitBreaker.trip(site, path, ttl)
        end

        reraise error, __STACKTRACE__
    end
  end

  defp do_mount_assigns(site, path, opts) do
    page_id = lookup_page!(site, path)
    manifest = fetch_manifest!(site, page_id)
    variant_roll = Keyword.get(opts, :variant_roll)
    path_info = String.split(String.trim_leading(path, "/"), "/", trim: true)
    path_params = extract_path_params(manifest.path, path_info)

    # Fetch DataStore sources BEFORE live_data so live_data code can reference them
    {data_store_assigns, data_source_names} = fetch_data_store_assigns(site, manifest, path_params, %{})

    # Evaluate live data at mount time so assigns are available for the initial render
    live_data = evaluate_live_data(site, page_id, path_info, %{})

    # Merge: DataStore results + live_data (live_data can override DataStore)
    all_data = Map.merge(data_store_assigns, live_data)

    beacon = %{
      site: site,
      path_params: path_params,
      query_params: %{},
      page: %{path: manifest.path, title: manifest.title},
      private: %{
        page_id: page_id,
        layout_id: manifest.layout_id,
        live_data_keys: Map.keys(all_data),
        data_source_names: data_source_names,
        live_path: path_info,
        variant_roll: variant_roll,
        page_type: Map.get(manifest.extra, "type", "default")
      }
    }

    page_title = interpolate_title(manifest.title, manifest, all_data)
    {:ok, Map.merge(all_data, %{beacon: beacon, page_title: page_title})}
  end

  # ---------------------------------------------------------------------------
  # Handle params — produces updated assigns on navigation
  # (replaces PageLive.handle_params logic)
  # ---------------------------------------------------------------------------

  @doc """
  Produces updated assigns for handle_params given a site, path, and params.

  This replaces the current flow of:
    RouterServer.lookup_page! → DataSource.live_data() → BeaconAssigns.new()

  Evaluates live_data definitions from ETS and merges everything into assigns.
  """
  def handle_params_assigns(site, path, params \\ %{}) when is_atom(site) and is_binary(path) do
    case Beacon.CircuitBreaker.check(site, path) do
      {:tripped, _remaining} -> raise Beacon.Web.ServerError, "page is temporarily unavailable"
      :ok -> :ok
    end

    try do
      do_handle_params_assigns(site, path, params)
    rescue
      error ->
        unless client_error?(error) do
          ttl = Beacon.Config.fetch!(site).circuit_breaker_ttl
          if ttl > 0, do: Beacon.CircuitBreaker.trip(site, path, ttl)
        end

        reraise error, __STACKTRACE__
    end
  end

  defp do_handle_params_assigns(site, path, params) do
    page_id = lookup_page!(site, path)
    manifest = fetch_manifest!(site, page_id)
    path_info = String.split(String.trim_leading(path, "/"), "/", trim: true)
    query_params = Map.drop(params, ["path"])
    path_params = extract_path_params(manifest.path, path_info)

    # Fetch DataStore sources BEFORE live_data
    {data_store_assigns, data_source_names} = fetch_data_store_assigns(site, manifest, path_params, query_params)

    # Evaluate live_data from stored definitions
    live_data = evaluate_live_data(site, page_id, path_info, query_params)

    all_data = Map.merge(data_store_assigns, live_data)

    beacon = %{
      site: site,
      path_params: path_params,
      query_params: query_params,
      live_data: all_data,
      page: %{path: manifest.path, title: manifest.title},
      private: %{
        page_id: page_id,
        layout_id: manifest.layout_id,
        live_data_keys: Map.keys(all_data),
        data_source_names: data_source_names,
        live_path: path_info,
        variant_roll: nil,
        page_type: Map.get(manifest.extra, "type", "default")
      }
    }

    page_title = interpolate_title(manifest.title, manifest, all_data)
    {:ok, Map.merge(all_data, %{beacon: beacon, page_title: page_title})}
  end

  # ---------------------------------------------------------------------------
  # DataStore integration
  # ---------------------------------------------------------------------------

  @doc """
  Returns the list of data source names used by a page, read from the manifest's extra field.
  """
  def page_data_source_names(site, page_id) do
    case fetch_manifest(site, page_id) do
      {:ok, manifest} ->
        manifest.extra
        |> Map.get("data_sources", [])
        |> Enum.map(fn spec -> spec["source"] || spec[:source] end)
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&safe_to_existing_atom/1)

      :error ->
        []
    end
  end

  defp fetch_data_store_assigns(site, manifest, path_params, query_params) do
    specs = Map.get(manifest.extra, "data_sources", [])

    if specs == [] do
      {%{}, []}
    else
      {assigns, source_names} =
        Enum.reduce(specs, {%{}, []}, fn spec, {acc, names} ->
          source_name =
            (spec["source"] || spec[:source])
            |> to_string()
            |> safe_to_existing_atom()

          case Beacon.DataStore.get_source(site, source_name) do
            nil ->
              Logger.warning("[Beacon.DataStore] data source #{inspect(source_name)} is referenced in page manifest but not registered for site #{inspect(site)}")
              {acc, names}

            _source ->
              raw_params = spec["params"] || spec[:params] || %{}
              resolved = resolve_data_store_params(raw_params, path_params, query_params)
              value = Beacon.DataStore.fetch(site, source_name, resolved)
              spread? = spec["spread"] == true || spec[:spread] == true

              updated_acc =
                if spread? and is_map(value) do
                  atomized = Map.new(value, fn {k, v} -> {safe_to_existing_atom(to_string(k)), v} end)
                  Map.merge(acc, atomized)
                else
                  Map.put(acc, source_name, value)
                end

              {updated_acc, [source_name | names]}
          end
        end)

      {assigns, Enum.reverse(source_names)}
    end
  end

  def resolve_data_store_params(param_spec, path_params, query_params) when is_map(param_spec) do
    Map.new(param_spec, fn
      {key, %{"path_param" => name}} -> {safe_to_existing_atom(key), Map.get(path_params, name) || Map.get(path_params, safe_to_existing_atom(name))}
      {key, %{"query_param" => name}} -> {safe_to_existing_atom(key), Map.get(query_params, name)}
      {key, %{"concat_path_params" => names}} when is_list(names) ->
        value = Enum.map_join(names, "/", fn n -> Map.get(path_params, n) || Map.get(path_params, safe_to_existing_atom(n)) || "" end)
        {safe_to_existing_atom(key), value}
      {key, {:path_param, name}} -> {safe_to_existing_atom(key), Map.get(path_params, name) || Map.get(path_params, safe_to_existing_atom(name))}
      {key, {:query_param, name}} -> {safe_to_existing_atom(key), Map.get(query_params, name)}
      {key, value} -> {safe_to_existing_atom(key), value}
    end)
  end

  def resolve_data_store_params(_, _, _), do: %{}

  # Interpolate snippets in page title (e.g., "{{ page.path }}", "{{ live_data.test }}")
  defp interpolate_title(title, manifest, live_data) do
    page_assigns = %{site: manifest.site, id: manifest.id, path: manifest.path, title: title, description: manifest.description}

    case Beacon.Content.render_snippet(title, %{page: page_assigns, live_data: live_data}) do
      {:ok, rendered} -> rendered
      {:error, _} -> title
    end
  rescue
    _ -> title
  end

  # ---------------------------------------------------------------------------
  # Live data evaluation (replaces compiled LiveData module)
  # ---------------------------------------------------------------------------

  @doc """
  Evaluates stored live_data definitions for a page.
  Each definition is a `%{key: atom, value: term, format: :text | :elixir}`.

  `:text` values are returned as-is.
  `:elixir` values are evaluated by the AST interpreter with path/query params in scope.
  """
  def evaluate_live_data(site, page_id, path_info, query_params) do
    defs =
      case :ets.lookup(@table, {site, page_id, :live_data}) do
        [{_, :no_live_data}] ->
          # Loaded previously but page has no live data definitions
          []

        [{_, defs}] when is_list(defs) ->
          defs

        _ ->
          # Lazy-load: fetch live_data from database and store in ETS
          lazy_load_live_data(site, page_id)
      end

    evaluate_live_data_defs(defs, path_info, query_params)
  end

  defp evaluate_live_data_defs(defs, path_info, query_params) when is_list(defs) do
    Enum.reduce(defs, %{}, fn
      %{key: key, value: value, format: :text}, acc ->
        Map.put(acc, key, value)

      %{key: key, value: code, format: :elixir} = def_entry, acc ->
        ast = Code.string_to_quoted!(code)
        path_vars = extract_path_variables(def_entry[:path_pattern], path_info)
        bindings = Map.merge(path_vars, %{path_info: path_info, params: query_params})

        result = eval_ast(ast, bindings)
        Map.put(acc, key, result)

      %{key: key, value: value}, acc ->
        Map.put(acc, key, value)
    end)
  end

  defp evaluate_live_data_defs(_, _path_info, _query_params), do: %{}

  defp lazy_load_live_data(site, page_id) do
    # Look up the page manifest to get the path pattern
    case fetch_manifest(site, page_id) do
      {:ok, manifest} ->
        # Query only the live data matching this page's path pattern,
        # not the entire site's live data. For static paths this is a
        # single-row query; for dynamic paths we fetch candidate patterns.
        matching_live_data = fetch_matching_live_data(site, manifest.path)

        defs =
          matching_live_data
          |> Enum.flat_map(fn ld ->
            Enum.map(ld.assigns, fn assign ->
              %{
                key: safe_to_existing_atom(assign.key),
                value: assign.value,
                format: assign.format,
                path_pattern: ld.path
              }
            end)
          end)

        if defs == [] do
          :ets.insert(@table, {{site, page_id, :live_data}, :no_live_data})
        else
          :ets.insert(@table, {{site, page_id, :live_data}, defs})
        end

        defs

      :error ->
        []
    end
  end

  defp fetch_matching_live_data(site, page_path) do
    # Try exact path match first (cheapest query)
    case Beacon.Content.get_live_data_by(site, path: page_path) do
      %{} = ld -> [ld]
      nil ->
        # No exact match — the page may use a different path pattern than
        # the live data (e.g., page path "/blog/:slug" vs live data path "/blog/:slug").
        # Query all live data paths and filter by pattern matching.
        # This is bounded by the number of live data definitions per site (typically < 30).
        Beacon.Content.live_data_for_site(site, per_page: :infinity)
        |> Enum.filter(fn ld -> path_matches_pattern?(ld.path, page_path) end)
    end
  end

  defp path_matches_pattern?(live_data_path, page_path) do
    ld_segments = String.split(String.trim_leading(live_data_path, "/"), "/", trim: true)
    page_segments = String.split(String.trim_leading(page_path, "/"), "/", trim: true)

    if length(ld_segments) != length(page_segments) do
      false
    else
      Enum.zip(ld_segments, page_segments)
      |> Enum.all?(fn
        {":" <> _, _} -> true
        {"*" <> _, _} -> true
        {_, ":" <> _} -> true
        {_, "*" <> _} -> true
        {a, b} -> a == b
      end)
    end
  end

  # Extract path variables from a pattern like "/blog/:year/:month/:day/:post_slug"
  # and actual path segments like ["blog", "2025", "05", "15", "my-post"]
  # Returns %{year: "2025", month: "05", day: "15", post_slug: "my-post"}
  defp extract_path_variables(nil, _path_info), do: %{}

  defp extract_path_variables(pattern, path_info) do
    pattern_segments = String.split(String.trim_leading(pattern, "/"), "/", trim: true)

    Enum.zip(pattern_segments, path_info)
    |> Enum.reduce(%{}, fn
      {":" <> param, value}, acc -> Map.put(acc, safe_to_existing_atom(param), value)
      {"*" <> param, value}, acc -> Map.put(acc, safe_to_existing_atom(param), value)
      _, acc -> acc
    end)
  end

  # Extract path params from a pattern like "/posts/:id" and actual path segments
  defp extract_path_params(pattern, path_info) do
    pattern_segments = String.split(String.trim_leading(pattern, "/"), "/", trim: true)

    Enum.zip(pattern_segments, path_info)
    |> Enum.reduce(%{}, fn
      {":" <> param, value}, acc -> Map.put(acc, param, value)
      {"*" <> param, value}, acc -> Map.put(acc, param, value)
      _, acc -> acc
    end)
  end

  # ---------------------------------------------------------------------------
  # Request time — render from IR (no code eval)
  # ---------------------------------------------------------------------------

  def render_page(site, page_id, assigns \\ %{}) when is_atom(site) do
    case :ets.lookup(@table, {site, page_id, :ir}) do
      [{_, serialized_ir}] ->
        ir = :erlang.binary_to_term(serialized_ir)
        stored_assigns = fetch_assigns(site, page_id)
        full_assigns = Map.merge(stored_assigns, assigns) |> Map.delete(:__changed__)
        {:ok, render_ir(ir, full_assigns)}

      [] ->
        {:error, :not_found}
    end
  end

  def render_to_string(site, page_id, assigns \\ %{}) do
    case render_page(site, page_id, assigns) do
      {:ok, rendered} ->
        {:ok, rendered |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Event handler dispatch (AST interpreter — no Code.eval)
  # ---------------------------------------------------------------------------

  def handle_event(site, page_id, event_name, event_params, socket) do
    case :ets.lookup(@table, {site, page_id, :handler, event_name}) do
      [{_, serialized_ast}] ->
        ast = :erlang.binary_to_term(serialized_ast)
        bindings = %{socket: socket, event_params: event_params}
        eval_ast(ast, bindings)

      [] ->
        {:error, {:no_handler, event_name}}
    end
  end

  # ---------------------------------------------------------------------------
  # State retrieval
  # ---------------------------------------------------------------------------

  def fetch_assigns(site, page_id) do
    case :ets.lookup(@table, {site, page_id, :assigns}) do
      [{_, assigns}] -> assigns
      [] -> %{}
    end
  end

  def list_handlers(site, page_id) do
    case :ets.lookup(@table, {site, page_id, :handler_index}) do
      [{_, names}] -> names
      [] -> []
    end
  end

  @doc """
  Stores a site-level handler (event or info) in ETS.
  These are global to the site, not scoped to a specific page.
  Any page on the site can dispatch them.
  """
  def store_site_handler(site, type, name, code) when type in [:event, :info] do
    handler_ast = Code.string_to_quoted!(code)
    :ets.insert(@table, {{site, :site_handler, type, name}, :erlang.term_to_binary(handler_ast)})

    # Maintain an index
    index_key = {site, :site_handler_index, type}

    existing =
      case :ets.lookup(@table, index_key) do
        [{_, names}] -> names
        [] -> []
      end

    unless name in existing do
      :ets.insert(@table, {index_key, [name | existing]})
    end

    :ok
  end

  @doc """
  Dispatches a site-level event handler. Falls back to page-level if not found at site level.
  """
  def handle_site_event(site, event_name, event_params, socket) do
    case :ets.lookup(@table, {site, :site_handler, :event, event_name}) do
      [{_, serialized_ast}] ->
        ast = :erlang.binary_to_term(serialized_ast)
        bindings = %{socket: socket, event_params: event_params}
        eval_ast(ast, bindings)

      [] ->
        # Lazy load event handlers for this site
        ensure_site_handlers_loaded(site, :event)

        case :ets.lookup(@table, {site, :site_handler, :event, event_name}) do
          [{_, serialized_ast}] ->
            ast = :erlang.binary_to_term(serialized_ast)
            bindings = %{socket: socket, event_params: event_params}
            eval_ast(ast, bindings)

          [] ->
            {:error, {:no_handler, event_name}}
        end
    end
  end

  def handle_site_info(site, msg, socket) do
    # Try all info handlers for the site
    case :ets.match(@table, {{site, :site_handler, :info, :"$1"}, :"$2"}) do
      [] ->
        # Lazy load info handlers then retry once
        ensure_site_handlers_loaded(site, :info)

        case :ets.match(@table, {{site, :site_handler, :info, :"$1"}, :"$2"}) do
          [] -> {:error, {:no_handler, msg}}
          handlers -> dispatch_info_handlers(handlers, msg, socket)
        end

      handlers ->
        dispatch_info_handlers(handlers, msg, socket)
    end
  end

  defp dispatch_info_handlers(handlers, msg, socket) do
    Enum.find_value(handlers, {:error, {:no_handler, msg}}, fn [name, serialized_ast] ->
      # Parse the handler's msg pattern and try to match it against the incoming message
      case match_info_pattern(name, msg) do
        {:ok, pattern_bindings} ->
          ast = :erlang.binary_to_term(serialized_ast)
          bindings = Map.merge(pattern_bindings, %{socket: socket, msg: msg})

          try do
            eval_ast(ast, bindings)
          rescue
            _ -> nil
          end

        :no_match ->
          nil
      end
    end)
  end

  # Match an info handler's msg pattern string against an actual message.
  # The pattern is a string like "{:incorrect_format, email}" that gets parsed
  # as an Elixir pattern and matched against the runtime message value.
  defp match_info_pattern(pattern_string, msg) when is_binary(pattern_string) do
    try do
      pattern_ast = Code.string_to_quoted!(pattern_string)
      match_pattern(pattern_ast, msg, %{})
    rescue
      _ -> :no_match
    end
  end

  defp ensure_site_handlers_loaded(site, type) do
    ttl = Beacon.Config.effective_ttl(Beacon.Config.fetch!(site), :handlers)

    Beacon.Cache.fetch(@table, {site, :handlers_load, type}, fn ->
      handlers =
        case type do
          :event -> Beacon.Content.list_event_handlers(site)
          :info -> Beacon.Content.list_info_handlers(site)
        end

      for handler <- handlers do
        name = if type == :event, do: handler.name, else: handler.msg
        store_site_handler(site, type, name, handler.code)
      end

      :loaded
    end, ttl)
  end

  def unpublish_page(site, page_id) do
    # Remove route mapping
    case fetch_manifest(site, page_id) do
      {:ok, manifest} -> :ets.delete(@table, {site, :route, manifest.path})
      _ -> :ok
    end

    :ets.delete(@table, {site, page_id, :ir})
    :ets.delete(@table, {site, page_id, :manifest})
    :ets.delete(@table, {site, page_id, :assigns})
    :ets.delete(@table, {site, page_id, :live_data})

    for name <- list_handlers(site, page_id) do
      :ets.delete(@table, {site, page_id, :handler, name})
    end

    :ets.delete(@table, {site, page_id, :handler_index})
    :ok
  end

  # ===========================================================================
  # IR Extraction — transforms HEEx AST into serializable data
  # ===========================================================================

  # Local calls that the IR evaluator handles directly — don't resolve via imports
  @beacon_local_calls ~w(my_component render_slot dynamic_helper beacon_asset_path beacon_asset_url sigil_p to_string __aliases__)a

  @doc false
  def extract_ir(ast, env \\ nil) do
    # Only the top-level call manages the process dictionary.
    # Nested calls (e.g. from inner_block extraction) must not clear it.
    is_owner = env != nil

    if is_owner do
      import_map = build_import_map(env)
      Process.put(:beacon_ir_imports, import_map)
    end

    try do
      {static, fingerprint, root, dynamics_ast} = extract_rendered_parts(ast)
      dynamics = extract_dynamics(dynamics_ast)
      %{static: static, dynamics: dynamics, fingerprint: fingerprint, root: root}
    after
      if is_owner, do: Process.delete(:beacon_ir_imports)
    end
  end

  defp build_import_map(%Macro.Env{functions: functions}) do
    Enum.flat_map(functions, fn {module, funs} ->
      Enum.map(funs, fn {fun, arity} -> {{fun, arity}, module} end)
    end)
    |> Map.new()
  end

  defp build_import_map(_), do: %{}

  # Walk the AST tree to find the dynamic fn and Rendered struct construction.
  # The HEEx AST nesting varies by Phoenix/Elixir version and template complexity.
  defp extract_rendered_parts(ast) do
    fn_ast = find_dynamic_fn(ast)
    {static, fingerprint, root} = find_rendered_fields(ast)
    {static, fingerprint, root, fn_ast}
  end

  # Recursively search for {:=, [], [{:dynamic, ...}, fn_def]}
  defp find_dynamic_fn({:=, [], [{:dynamic, [], _}, fn_ast]}), do: fn_ast

  defp find_dynamic_fn({:__block__, [], children}) when is_list(children) do
    Enum.find_value(children, fn child -> find_dynamic_fn(child) end)
  end

  defp find_dynamic_fn(_), do: nil

  # Recursively search for %Phoenix.LiveView.Rendered{...} struct construction
  defp find_rendered_fields({:%, [], [_aliases, {:%{}, [], fields}]}) do
    static = Keyword.fetch!(fields, :static)
    fingerprint = Keyword.fetch!(fields, :fingerprint)
    root = Keyword.get(fields, :root, false)
    {static, fingerprint, root}
  end

  defp find_rendered_fields({:__block__, [], children}) when is_list(children) do
    Enum.find_value(children, fn child -> find_rendered_fields(child) end)
  end

  defp find_rendered_fields(_), do: nil

  # Extract individual dynamic expressions from the fn body.
  # The fn body structure:
  #   fn track_changes? ->
  #     changed = case assigns ...   (change tracking setup)
  #     __block__                    (variable assignments)
  #       v0 = case ...
  #       v1 = case ...
  #     [v0, v1, ...]               (return list)
  #   end
  defp extract_dynamics({:fn, [], [{:->, [], [[_track_changes], body]}]}) do
    {:__block__, [], [_changed_setup | rest]} = body

    {all_assigns, return_vars} =
      case rest do
        # No dynamic expressions (static template): empty block + empty list
        [{:__block__, [], []}, []] -> {[], []}
        # Multiple dynamic expressions: __block__ wrapping assignments + return list
        [{:__block__, [], assigns}, return_list] when is_list(assigns) -> {assigns, return_list}
        # Single dynamic expression: one assignment + return list
        [{:=, _, _} = single_assign, return_list] -> {[single_assign], return_list}
        # Fallback
        _ -> {[], []}
      end

    # Identify which variable names appear in the return list (these are the output dynamics)
    output_var_names = MapSet.new(Enum.map(return_vars, fn {name, _, _} -> name end))

    # Separate local bindings from output dynamics
    {local_bindings, output_assigns} =
      Enum.split_with(all_assigns, fn
        {:=, _, [{name, _, ctx}, _]} when is_atom(name) and is_atom(ctx) ->
          # User-defined variable (context is nil for user vars, Engine for generated)
          ctx != Phoenix.LiveView.Engine and not MapSet.member?(output_var_names, name)

        _ ->
          false
      end)

    # Convert local bindings to IR bind nodes
    binding_irs =
      Enum.map(local_bindings, fn {:=, _, [{name, _, _}, value_ast]} ->
        %{deps: [], expr: {:bind, name, transform_expr(value_ast)}}
      end)

    # Extract output dynamics normally
    output_irs = Enum.map(output_assigns, &extract_one_dynamic/1)

    binding_irs ++ output_irs
  end

  defp extract_one_dynamic({:=, _meta, [{_var, _, _}, case_expr]}) do
    extract_case_expr(case_expr)
  end

  # Standard pattern: case Engine.changed_assign?(changed, :key) do true -> expr; false -> nil end
  defp extract_case_expr({:case, _meta, [changed_check, [do: clauses]]}) do
    deps = extract_deps(changed_check)
    expr = extract_true_branch(clauses)
    %{deps: deps, expr: transform_expr(expr)}
  end

  # Comprehensions don't use the simple changed_assign? pattern — handle them
  defp extract_case_expr(other) do
    %{deps: [], expr: transform_expr(other)}
  end

  defp extract_deps({{:., [], [Phoenix.LiveView.Engine, :changed_assign?]}, [], [_changed, key]}) do
    [key]
  end

  defp extract_deps(_), do: []

  # Standard assign pattern: true -> expr; false -> nil
  defp extract_true_branch([{:->, _, [[true], expr]} | _]), do: expr
  # Component pattern: %{} -> nil; _ -> expr (empty map = no change, wildcard = evaluate)
  defp extract_true_branch([{:->, _, [[{:%{}, _, []}], nil]}, {:->, _, [[{:_, _, _}], expr]}]), do: expr
  defp extract_true_branch(_), do: {:literal, nil}

  # ===========================================================================
  # Expression transformation — HEEx AST nodes → IR expression descriptors
  # ===========================================================================

  # live_to_iodata(expr) — unwrap and transform inner expression
  defp transform_expr({{:., _, [Phoenix.LiveView.Engine, :live_to_iodata]}, _, [inner]}) do
    {:iodata, transform_expr(inner)}
  end

  # assigns.key
  defp transform_expr({{:., _, [{:assigns, [], _}, key]}, _, []}) when is_atom(key) do
    {:assign, key}
  end

  # Nested dot access: expr.key
  defp transform_expr({{:., _, [inner, key]}, _, []}) when is_atom(key) do
    {:dot, transform_expr(inner), key}
  end

  # Calling a function stored in a variable/assign: expr.(args)
  # e.g., @route.(@current_page - 1), fun.(arg)
  defp transform_expr({{:., _, [callee]}, _, args}) when is_list(args) do
    {:fun_call, transform_expr(callee), Enum.map(args, &transform_expr/1)}
  end

  # Unary operators
  defp transform_expr({:!, _, [expr]}), do: {:op, :!, [transform_expr(expr)]}
  defp transform_expr({:not, _, [expr]}), do: {:op, :not, [transform_expr(expr)]}

  # if/else — branches may contain nested %Rendered{} structs
  defp transform_expr({:if, _, [cond_expr, [do: then_expr, else: else_expr]]}) do
    then_ir = transform_branch(then_expr)
    else_ir = transform_branch(else_expr)
    {:if, transform_expr(cond_expr), then_ir, else_ir}
  end

  defp transform_expr({:if, _, [cond_expr, [do: then_expr]]}) do
    {:if, transform_expr(cond_expr), transform_branch(then_expr), {:literal, nil}}
  end

  # String interpolation: {:<<>>, _, parts}
  defp transform_expr({:<<>>, _, parts}) do
    {:interpolation, Enum.map(parts, &transform_interpolation_part/1)}
  end

  # Tuple construction: {a, b}
  defp transform_expr({:{}, _, elements}) do
    {:tuple, Enum.map(elements, &transform_expr/1)}
  end

  # Two-element tuple (special AST form)
  # {:safe, string} — pre-escaped HTML attribute name (e.g., "phx-click", "src")
  defp transform_expr({:safe, value}) when is_binary(value) do
    {:safe_literal, value}
  end

  # {:safe, ast} — runtime encoding call wrapped in safe marker
  # (e.g., class_attribute_encode, binary_encode)
  defp transform_expr({:safe, expr}) do
    {:safe_expr, transform_expr(expr)}
  end

  # Atom-keyed tuple — component attribute (e.g., {:class, "foo"}, {:post, expr})
  defp transform_expr({key, value}) when is_atom(key) do
    {:tuple, [{:literal, key}, transform_expr(value)]}
  end

  defp transform_expr({left, right}) when not is_list(right) and not is_atom(left) do
    {:tuple, [transform_expr(left), transform_expr(right)]}
  end

  # Map access: map[key]
  defp transform_expr({{:., _, [Access, :get]}, _, [map_expr, key_expr]}) do
    {:access, transform_expr(map_expr), transform_expr(key_expr)}
  end

  # Variable reference (for comprehension bodies)
  defp transform_expr({name, _, nil}) when is_atom(name) do
    {:var, name}
  end

  defp transform_expr({name, _, ctx}) when is_atom(name) and is_atom(ctx) do
    {:var, name}
  end

  # Comprehension block — produces %Comprehension{} struct
  defp transform_expr({:__block__, _meta, block_parts}) when is_list(block_parts) do
    # Look for Comprehension.__annotate__ call
    case find_comprehension(block_parts) do
      {:ok, comp_ir} -> comp_ir
      :not_found -> {:block, Enum.map(block_parts, &transform_expr/1)}
    end
  end

  # Phoenix.LiveView.TagEngine.component(&fun/1, assigns, caller) — function component calls
  # Extract the function reference and assigns, store as {:component_call, ...}
  defp transform_expr({{:., _, [{:__aliases__, _, [:Phoenix, :LiveView, :TagEngine]}, :component]}, _meta, args}) do
    case args do
      [fun_capture, assigns_map, _caller] ->
        fun_ir = extract_component_fun(fun_capture)
        assigns_ir = extract_component_assigns(assigns_map)
        {:component_call, fun_ir, assigns_ir}

      _ ->
        {:literal, ""}
    end
  end

  # Phoenix.LiveView.Engine.to_component_static — used in component change tracking
  defp transform_expr({{:., _, [Phoenix.LiveView.Engine, :to_component_static]}, _, _args}) do
    {:literal, %{}}
  end

  # Phoenix.LiveView.TagEngine.inner_block — slot content for components
  defp transform_expr({{:., _, [{:__aliases__, _, [:Phoenix, :LiveView, :TagEngine]}, :inner_block]}, _, inner_args}) do
    # inner_block(:inner_block, [do: [{->, [_], body}]])
    case inner_args do
      [:inner_block, [do: [{:->, _meta, [slot_args, body]}]]] ->
        # Capture the :let variable name (e.g., :let={f} → :f)
        let_var =
          case slot_args do
            [{name, _, _}] when is_atom(name) and name != :_ -> name
            _ -> nil
          end

        {:inner_block_ir, extract_ir(body), let_var}

      _ ->
        {:literal, ""}
    end
  end

  # Phoenix.LiveView.Comprehension.__annotate__(struct, enum)
  defp transform_expr({{:., [], [{:__aliases__, _, [:Phoenix, :LiveView, :Comprehension]}, :__annotate__]}, [], [comp_struct, _enum]}) do
    transform_comprehension(comp_struct, nil)
  end

  # Phoenix.LiveView.Comprehension.__mark_consumable__(enum)
  defp transform_expr({{:., [], [{:__aliases__, _, [:Phoenix, :LiveView, :Comprehension]}, :__mark_consumable__]}, [], [enum_expr]}) do
    transform_expr(enum_expr)
  end

  # List literal
  defp transform_expr(list) when is_list(list) do
    {:list, Enum.map(list, &transform_expr/1)}
  end

  # Literal values
  defp transform_expr(value) when is_binary(value), do: {:literal, value}
  defp transform_expr(value) when is_integer(value), do: {:literal, value}
  defp transform_expr(value) when is_float(value), do: {:literal, value}
  defp transform_expr(value) when is_boolean(value), do: {:literal, value}
  defp transform_expr(nil), do: {:literal, nil}
  defp transform_expr(value) when is_atom(value), do: {:literal, value}

  # Map literal with keyword-style atoms: {:%{}, [], [key: value, ...]}
  defp transform_expr({:%{}, _, pairs}) when is_list(pairs) do
    {:map_literal,
     Enum.map(pairs, fn
       {key, value} when is_atom(key) -> {key, transform_expr(value)}
       {key, value} -> {transform_expr(key), transform_expr(value)}
     end)}
  end

  # Anonymous function: fn args -> body end
  defp transform_expr({:fn, _, clauses}) when is_list(clauses) do
    transformed_clauses =
      Enum.map(clauses, fn {:->, _, [params, body]} ->
        param_names = Enum.map(params, &extract_var_name/1)
        {:clause, param_names, transform_expr(body)}
      end)

    {:anon_fn, transformed_clauses}
  end

  # Function capture: &fun/arity
  defp transform_expr({:&, _, _}), do: {:literal, nil}

  # Catch-all for assignment expressions (e.g. {:=, [], [pattern, value]})
  defp transform_expr({:=, _, [_pattern, value]}) do
    transform_expr(value)
  end

  # Catch-all for case (used inside comprehension change tracking)
  defp transform_expr({:case, _, [_check, [do: clauses]]}) do
    # Take the true branch if available
    case clauses do
      [{:->, [], [[true], expr]} | _] -> transform_expr(expr)
      [{:->, [], [_, expr]} | _] -> transform_expr(expr)
      _ -> {:literal, nil}
    end
  end

  # for comprehension expression
  defp transform_expr({:for, _, [{:<-, _, [binding, enum_expr]} | opts]}) do
    var_name = extract_var_name(binding)
    body = Keyword.get(opts, :do, nil)
    {:for_expr, var_name, transform_expr(enum_expr), transform_expr(body)}
  end

  # Function call on module: Module.fun(args)
  defp transform_expr({{:., _, [module, fun]}, _, args}) when is_atom(module) and is_atom(fun) do
    {:call, module, fun, Enum.map(args, &transform_expr/1)}
  end

  # Binary operators — MUST come before the local_call catch-all below,
  # otherwise {:<>, meta, [l, r]} matches {fun, _, args} first and becomes
  # {:local_call, :<>, ...} which crashes with apply(Kernel, :<>, ...) since
  # <>, &&, || are Kernel macros, not runtime functions.
  @binary_ops [:+, :-, :*, :/, :==, :!=, :<, :>, :<=, :>=, :&&, :||, :<>, :rem]
  defp transform_expr({op, _, [left, right]}) when op in @binary_ops do
    {:op, op, [transform_expr(left), transform_expr(right)]}
  end

  # Local calls: resolve imported functions to module-qualified calls,
  # except for Beacon-specific local calls handled by dedicated eval_ir clauses.
  defp transform_expr({fun, _, args}) when is_atom(fun) and is_list(args) do
    transformed_args = Enum.map(args, &transform_expr/1)

    if fun in @beacon_local_calls do
      {:local_call, fun, transformed_args}
    else
      import_map = Process.get(:beacon_ir_imports, %{})

      case Map.get(import_map, {fun, length(args)}) do
        nil -> {:local_call, fun, transformed_args}
        module -> {:call, module, fun, transformed_args}
      end
    end
  end

  # Module-qualified calls via __aliases__ (e.g., Foo.Bar.baz(args))
  defp transform_expr({{:., _, [{:__aliases__, _, mod_parts}, fun]}, _, args}) when is_atom(fun) and is_list(args) do
    module = Module.concat(mod_parts)
    {:call, module, fun, Enum.map(args, &transform_expr/1)}
  end

  # Catch-all: log the unhandled AST for debugging, return empty literal
  defp transform_expr(other) do
    require Logger
    Logger.warning("[RuntimeRenderer] Unhandled transform_expr AST: #{inspect(other, limit: 200)}")
    {:literal, ""}
  end

  # Check if a branch contains a nested %Rendered{} struct (common in if/else/case)
  defp transform_branch({:__block__, [], parts}) do
    case find_rendered_fields_in_list(parts) do
      nil ->
        {:block, Enum.map(parts, &transform_expr/1)}

      {static, fingerprint, root} ->
        fn_ast =
          Enum.find_value(parts, fn
            {:=, [], [{:dynamic, [], _}, fn_def]} -> fn_def
            _ -> nil
          end)

        dynamics = if fn_ast, do: extract_dynamics(fn_ast), else: []
        {:nested_rendered, %{static: static, dynamics: dynamics, fingerprint: fingerprint, root: root}}
    end
  end

  defp transform_branch(expr), do: transform_expr(expr)

  defp find_rendered_fields_in_list(parts) when is_list(parts) do
    Enum.find_value(parts, fn
      {:%, [], [_aliases, {:%{}, [], fields}]} ->
        if Keyword.has_key?(fields, :static) and Keyword.has_key?(fields, :fingerprint) do
          static = Keyword.fetch!(fields, :static)
          fingerprint = Keyword.fetch!(fields, :fingerprint)
          root = Keyword.get(fields, :root, false)
          {static, fingerprint, root}
        end

      _ ->
        nil
    end)
  end

  # Extract function capture from component call: &link/1 → {Phoenix.Component, :link}
  defp extract_component_fun({:&, _, [{:/, _, [{fun_name, _, _ctx}, arity]}]}) when is_atom(fun_name) do
    # Bare function capture like &header/1 from <.header>.
    # Only resolve to Phoenix.Component if the function actually exists there.
    # Otherwise it's likely a Beacon CMS component — return nil so eval_ir
    # falls through to the component lookup path.
    if function_exported?(Phoenix.Component, fun_name, arity) do
      {:component_fun, Phoenix.Component, fun_name}
    else
      {:component_fun, nil, fun_name}
    end
  end

  defp extract_component_fun({:&, _, [{:/, _, [{{:., _, [{:__aliases__, _, mod_parts}, fun_name]}, _, _}, _arity]}]}) do
    {:component_fun, Module.concat(mod_parts), fun_name}
  end

  defp extract_component_fun(other) do
    require Logger
    Logger.warning("[RuntimeRenderer] Unhandled component capture AST: #{inspect(other, limit: 200)}")
    {:component_fun, nil, nil}
  end

  # Extract component assigns map, transforming inner_block slots
  defp extract_component_assigns({:%{}, _, pairs}) do
    transformed =
      Enum.map(pairs, fn
        {:__changed__, _} ->
          {:__changed__, {:literal, nil}}

        {:inner_block, slots} when is_list(slots) ->
          slot_irs =
            Enum.map(slots, fn
              {:%{}, _, slot_pairs} ->
                Enum.into(slot_pairs, %{}, fn
                  {:__slot__, name} -> {:__slot__, name}
                  {:inner_block, block_ast} -> {:inner_block, transform_expr(block_ast)}
                  {k, v} -> {k, transform_expr(v)}
                end)

              other ->
                other
            end)

          {:inner_block, {:literal, slot_irs}}

        {key, value} ->
          {key, transform_expr(value)}
      end)

    {:component_assigns, transformed}
  end

  # Handle to_component_dynamic — produced when @rest spreads are used in component calls.
  # The args are: [base_map, rest_map, defaults_map, rest_keys_list, assigns, changed]
  # We extract the base_map's pairs (which contain inner_block) and mark the rest for runtime merge.
  defp extract_component_assigns({{:., _, [Phoenix.LiveView.Engine, :to_component_dynamic]}, _, args}) do
    case args do
      [{:%{}, _, base_pairs} | rest_args] ->
        # Extract the base pairs just like the normal map case
        transformed_base =
          Enum.map(base_pairs, fn
            {:__changed__, _} ->
              {:__changed__, {:literal, nil}}

            {:inner_block, slots} when is_list(slots) ->
              slot_irs =
                Enum.map(slots, fn
                  {:%{}, _, slot_pairs} ->
                    Enum.into(slot_pairs, %{}, fn
                      {:__slot__, name} -> {:__slot__, name}
                      {:inner_block, block_ast} -> {:inner_block, transform_expr(block_ast)}
                      {k, v} -> {k, transform_expr(v)}
                    end)

                  other ->
                    other
                end)

              {:inner_block, {:literal, slot_irs}}

            {key, value} ->
              {key, transform_expr(value)}
          end)

        # The rest map is the second argument — transform it for runtime merge
        rest_ir = case rest_args do
          [rest_map_ast | _] -> transform_expr(rest_map_ast)
          _ -> {:literal, %{}}
        end

        {:component_assigns_dynamic, transformed_base, rest_ir}

      _ ->
        transform_expr({{:., [], [Phoenix.LiveView.Engine, :to_component_dynamic]}, [], args})
    end
  end

  defp extract_component_assigns(other), do: transform_expr(other)

  defp transform_interpolation_part({:"::", _, [expr, {:binary, _, _}]}) do
    transform_expr(expr)
  end

  defp transform_interpolation_part(binary) when is_binary(binary) do
    {:literal, binary}
  end

  defp find_comprehension(parts) do
    # First, find the enum source from __mark_consumable__(assigns.xxx)
    enum_source =
      Enum.find_value(parts, nil, fn
        {:=, [], [{:for, _, _}, {{:., [], [{:__aliases__, _, [:Phoenix, :LiveView, :Comprehension]}, :__mark_consumable__]}, [], [enum_expr]}]} ->
          transform_expr(enum_expr)

        _ ->
          nil
      end)

    Enum.find_value(parts, :not_found, fn
      {{:., [], [{:__aliases__, _, [:Phoenix, :LiveView, :Comprehension]}, :__annotate__]}, [], [comp, _]} ->
        {:ok, transform_comprehension(comp, enum_source)}

      _ ->
        nil
    end)
  end

  defp transform_comprehension({:%, [], [_aliases, {:%{}, [], fields}]}, enum_source) do
    static = Keyword.fetch!(fields, :static)
    fingerprint = Keyword.fetch!(fields, :fingerprint)
    dynamics_expr = Keyword.fetch!(fields, :dynamics)

    # The dynamics is a `for` comprehension. Extract var name and body,
    # but replace the enum with the actual source (from __mark_consumable__).
    dynamics_ir = transform_for_dynamics(dynamics_expr, enum_source)

    {:comprehension, %{static: static, fingerprint: fingerprint, dynamics: dynamics_ir}}
  end

  defp transform_for_dynamics({:for, _, [{:<-, _, [binding, _for_var]}, [do: body]]}, enum_source) do
    var_name = extract_var_name(binding)
    {:for_expr, var_name, enum_source || {:literal, []}, transform_for_body(body)}
  end

  defp transform_for_dynamics(other, _enum_source), do: transform_expr(other)

  # The for body is typically: __block__ [v0 = live_to_iodata(item), [v0]]
  # We need to extract the actual expressions and return them as a list.
  # Some for bodies also contain local variable assignments from <% var = expr %>.
  defp transform_for_body({:__block__, [], parts}) do
    # The last element is the return list of variable refs (e.g., [v0, v1])
    return_list = List.last(parts)

    output_var_names =
      case return_list do
        vars when is_list(vars) ->
          MapSet.new(Enum.map(vars, fn {name, _, _} -> name end))

        _ ->
          MapSet.new()
      end

    # All assignments in the block
    all_assigns =
      Enum.filter(parts, fn
        {:=, [], [{_var, [], _}, _expr]} -> true
        _ -> false
      end)

    # Separate local bindings from output assignments
    {local_bindings, output_assigns} =
      Enum.split_with(all_assigns, fn {:=, [], [{name, [], ctx}, _expr]} ->
        ctx != Phoenix.LiveView.Engine and not MapSet.member?(output_var_names, name)
      end)

    # Build IR: local bindings as {:bind, ...}, then output expressions as a list
    binding_irs =
      Enum.map(local_bindings, fn {:=, [], [{name, _, _}, value_ast]} ->
        {:bind, name, transform_expr(value_ast)}
      end)

    output_irs = Enum.map(output_assigns, fn {:=, [], [_var, expr]} -> transform_expr(expr) end)

    case binding_irs do
      [] -> {:list, output_irs}
      _ -> {:for_body_with_bindings, binding_irs, {:list, output_irs}}
    end
  end

  defp transform_for_body(other), do: transform_expr(other)

  defp extract_var_name({name, _, _}) when is_atom(name), do: name
  defp extract_var_name(name) when is_atom(name), do: name

  # 2-element tuple destructuring: {a, b}
  defp extract_var_name({a, b}) when is_tuple(a) and is_tuple(b) do
    {:destructure, :tuple, [extract_var_name(a), extract_var_name(b)]}
  end

  # N-element tuple destructuring: {a, b, c, ...}
  defp extract_var_name({:{}, _, elements}) when is_list(elements) do
    {:destructure, :tuple, Enum.map(elements, &extract_var_name/1)}
  end

  # Fallback
  defp extract_var_name(_), do: :_item

  # Coerce nil dynamic results to empty string to prevent LiveView diff errors
  defp safe_dynamic(nil), do: ""
  defp safe_dynamic({:safe, data}), do: data
  defp safe_dynamic(value), do: value

  # Safely convert a value to a map for component assigns
  defp safe_to_map(%{} = map), do: map

  defp safe_to_map(list) when is_list(list) do
    if Enum.all?(list, &is_tuple/1) and Enum.all?(list, fn t -> tuple_size(t) == 2 end) do
      Map.new(list)
    else
      %{}
    end
  end

  defp safe_to_map(_), do: %{}

  # Build inner_block slot entries for CMS components from IR slot descriptors
  defp build_cms_inner_block(slot_irs, a, b) when is_list(slot_irs) do
    Enum.map(slot_irs, fn
      %{__slot__: name, inner_block: block_ir} ->
        inner_fn = fn _changed, slot_arg ->
          case block_ir do
            {:inner_block_ir, ir, let_var} when is_atom(let_var) and not is_nil(let_var) ->
              inner_assigns =
                Map.merge(a, b)
                |> Map.put(let_var, slot_arg)
                |> Map.delete(:__changed__)

              render_ir(ir, inner_assigns)

            {:inner_block_ir, ir, _} ->
              render_ir(ir, Map.merge(a, b))

            {:inner_block_ir, ir} ->
              render_ir(ir, Map.merge(a, b))

            _ ->
              ""
          end
        end

        %{__slot__: name, inner_block: inner_fn}

      slot ->
        slot
    end)
  end

  defp build_cms_inner_block(_, _a, _b), do: []

  # Bind a for-loop variable, handling destructuring patterns
  defp destructure_binding(bindings, {:destructure, :tuple, names}, item) when is_tuple(item) do
    values = Tuple.to_list(item)

    names
    |> Enum.zip(values)
    |> Enum.reduce(bindings, fn {name, value}, acc ->
      Map.put(acc, name, value)
    end)
  end

  defp destructure_binding(bindings, name, item) when is_atom(name) do
    Map.put(bindings, name, item)
  end

  # ===========================================================================
  # IR Renderer — constructs %Rendered{} from IR + assigns (no code eval)
  # ===========================================================================

  def render_ir(ir, assigns) do
    %Phoenix.LiveView.Rendered{
      static: ir.static,
      dynamic: &evaluate_dynamics(ir.dynamics, assigns, &1),
      fingerprint: ir.fingerprint,
      root: Map.get(ir, :root, false),
      caller: :not_available
    }
  end

  defp evaluate_dynamics(dynamics, assigns, track_changes?) do
    changed = if track_changes?, do: Map.get(assigns, :__changed__), else: nil

    {results, _bindings} =
      Enum.reduce(dynamics, {[], %{}}, fn %{deps: deps, expr: expr}, {acc, bindings} ->
        case expr do
          {:bind, name, value_expr} ->
            value = eval_ir(value_expr, assigns, bindings)
            {acc, Map.put(bindings, name, value)}

          _ ->
            if changed != nil and deps != [] and not Enum.any?(deps, &Map.has_key?(changed, &1)) do
              {[nil | acc], bindings}
            else
              result = eval_ir(expr, assigns, bindings)
              {[safe_dynamic(result) | acc], bindings}
            end
        end
      end)

    Enum.reverse(results)
  end

  # Evaluate an IR expression with assigns and local bindings (for comprehension vars)
  defp eval_ir({:iodata, inner}, assigns, bindings) do
    case eval_ir(inner, assigns, bindings) do
      nil -> ""
      value -> Phoenix.LiveView.Engine.live_to_iodata(value)
    end
  end

  defp eval_ir({:assign, key}, assigns, _bindings), do: Map.get(assigns, key)

  # {:safe, ...} — pre-escaped HTML content, reconstruct the tuple for Phoenix.HTML
  defp eval_ir({:safe_literal, value}, _assigns, _bindings), do: {:safe, value}
  defp eval_ir({:safe_expr, expr}, assigns, bindings), do: {:safe, eval_ir(expr, assigns, bindings)}

  defp eval_ir({:dot, inner, key}, assigns, bindings) do
    value = eval_ir(inner, assigns, bindings)

    cond do
      is_nil(value) ->
        nil

      is_atom(value) ->
        Code.ensure_loaded(value)

        if function_exported?(value, key, 0) do
          apply(value, key, [])
        else
          nil
        end

      is_map(value) ->
        Map.get(value, key)

      true ->
        nil
    end
  end

  defp eval_ir({:literal, value}, _assigns, _bindings), do: value

  # Calling a function stored in a variable/assign: fun.(args)
  defp eval_ir({:fun_call, callee_ir, arg_irs}, assigns, bindings) do
    fun = eval_ir(callee_ir, assigns, bindings)
    args = Enum.map(arg_irs, &eval_ir(&1, assigns, bindings))

    if is_function(fun, length(args)) do
      apply(fun, args)
    else
      nil
    end
  end

  # Anonymous function: fn args -> body end
  defp eval_ir({:anon_fn, clauses}, assigns, bindings) do
    fn_clauses = clauses

    # Build a function that pattern-matches the first clause
    # (simplified: supports single-clause fns which covers the common case)
    case fn_clauses do
      [{:clause, param_names, body_ir}] ->
        case length(param_names) do
          0 -> fn -> eval_ir(body_ir, assigns, bindings) end
          1 -> fn arg1 -> eval_ir(body_ir, assigns, Map.put(bindings, hd(param_names), arg1)) end
          2 -> fn arg1, arg2 ->
            b = bindings |> Map.put(Enum.at(param_names, 0), arg1) |> Map.put(Enum.at(param_names, 1), arg2)
            eval_ir(body_ir, assigns, b)
          end
          _ -> fn -> eval_ir(body_ir, assigns, bindings) end
        end

      _ ->
        # Multi-clause: use first clause as fallback
        [{:clause, param_names, body_ir} | _] = fn_clauses
        case length(param_names) do
          0 -> fn -> eval_ir(body_ir, assigns, bindings) end
          1 -> fn arg1 -> eval_ir(body_ir, assigns, Map.put(bindings, hd(param_names), arg1)) end
          _ -> fn -> eval_ir(body_ir, assigns, bindings) end
        end
    end
  end

  # The bare `assigns` variable in HEEx refers to the entire assigns map
  defp eval_ir({:var, :assigns}, assigns, _bindings), do: assigns

  defp eval_ir({:var, name}, assigns, bindings) do
    Map.get(bindings, name, Map.get(assigns, name))
  end

  defp eval_ir({:op, :+, [l, r]}, a, b), do: eval_ir(l, a, b) + eval_ir(r, a, b)
  defp eval_ir({:op, :-, [l, r]}, a, b), do: eval_ir(l, a, b) - eval_ir(r, a, b)
  defp eval_ir({:op, :*, [l, r]}, a, b), do: eval_ir(l, a, b) * eval_ir(r, a, b)
  defp eval_ir({:op, :/, [l, r]}, a, b), do: eval_ir(l, a, b) / eval_ir(r, a, b)
  defp eval_ir({:op, :==, [l, r]}, a, b), do: eval_ir(l, a, b) == eval_ir(r, a, b)
  defp eval_ir({:op, :!=, [l, r]}, a, b), do: eval_ir(l, a, b) != eval_ir(r, a, b)
  defp eval_ir({:op, :<, [l, r]}, a, b), do: eval_ir(l, a, b) < eval_ir(r, a, b)
  defp eval_ir({:op, :>, [l, r]}, a, b), do: eval_ir(l, a, b) > eval_ir(r, a, b)
  defp eval_ir({:op, :<=, [l, r]}, a, b), do: eval_ir(l, a, b) <= eval_ir(r, a, b)
  defp eval_ir({:op, :>=, [l, r]}, a, b), do: eval_ir(l, a, b) >= eval_ir(r, a, b)
  defp eval_ir({:op, :&&, [l, r]}, a, b), do: eval_ir(l, a, b) && eval_ir(r, a, b)
  defp eval_ir({:op, :||, [l, r]}, a, b), do: eval_ir(l, a, b) || eval_ir(r, a, b)
  defp eval_ir({:op, :<>, [l, r]}, a, b), do: (eval_ir(l, a, b) || "") <> (eval_ir(r, a, b) || "")
  defp eval_ir({:op, :rem, [l, r]}, a, b), do: rem(eval_ir(l, a, b), eval_ir(r, a, b))
  defp eval_ir({:op, :!, [expr]}, a, b), do: !eval_ir(expr, a, b)
  defp eval_ir({:op, :not, [expr]}, a, b), do: not eval_ir(expr, a, b)

  defp eval_ir({:if, cond_ir, then_ir, else_ir}, a, b) do
    if eval_ir(cond_ir, a, b), do: eval_ir(then_ir, a, b), else: eval_ir(else_ir, a, b)
  end

  # Nested Rendered struct (produced by if/else branches in HEEx)
  # Must pass bindings through so comprehension loop variables (e.g. `employee`)
  # are available when LiveView's diff system evaluates the Rendered's dynamics.
  defp eval_ir({:nested_rendered, ir}, assigns, bindings) do
    render_ir_with_bindings(ir, assigns, bindings)
  end

  # Phoenix function component call — call the actual component function
  defp eval_ir({:component_call, {:component_fun, mod, fun}, {:component_assigns, pairs}}, a, b) when is_atom(mod) and is_atom(fun) and not is_nil(mod) and not is_nil(fun) do
    component_assigns =
      Enum.reduce(pairs, %{}, fn
        {:__changed__, _}, acc ->
          Map.put(acc, :__changed__, nil)

        {:inner_block, {:literal, slot_irs}}, acc ->
          rendered_slots =
            Enum.map(slot_irs, fn
              %{__slot__: name, inner_block: block_ir} ->
                # Phoenix render_slot calls: entry.inner_block.(changed, argument)
                # First param is change tracking, second is the slot argument (e.g. form struct)
                inner_fn = fn _changed, slot_arg ->
                  case block_ir do
                    {:inner_block_ir, ir, let_var} when is_atom(let_var) and not is_nil(let_var) ->
                      inner_assigns =
                        Map.merge(a, b)
                        |> Map.put(let_var, slot_arg)
                        |> Map.delete(:__changed__)

                      render_ir(ir, inner_assigns)

                    {:inner_block_ir, ir, _} ->
                      render_ir(ir, Map.merge(a, b))

                    {:inner_block_ir, ir} ->
                      render_ir(ir, Map.merge(a, b))

                    _ ->
                      ""
                  end
                end

                %{__slot__: name, inner_block: inner_fn}

              slot ->
                slot
            end)

          Map.put(acc, :inner_block, rendered_slots)

        {key, value_ir}, acc ->
          Map.put(acc, key, eval_ir(value_ir, a, b))
      end)
      |> Map.put_new(:__changed__, nil)

    apply(mod, fun, [component_assigns])
  end

  # Unresolved component call (nil module) — try as a Beacon CMS component
  defp eval_ir({:component_call, {:component_fun, nil, fun_name}, {:component_assigns, pairs}}, a, b) when is_atom(fun_name) do
    # Try as a Phoenix built-in component first (e.g., <.link>, <.form>, <.inputs_for>)
    if function_exported?(Phoenix.Component, fun_name, 1) do
      eval_ir({:component_call, {:component_fun, Phoenix.Component, fun_name}, {:component_assigns, pairs}}, a, b)
    else
      site = Map.get(a, :beacon, %{}) |> Map.get(:site)
      component_name = Atom.to_string(fun_name)

      if site do
        component_assigns =
          Enum.reduce(pairs, %{}, fn
            {:__changed__, _}, acc -> Map.put(acc, :__changed__, nil)
            {:inner_block, {:literal, slot_irs}}, acc ->
              rendered_slots = build_cms_inner_block(slot_irs, a, b)
              Map.put(acc, :inner_block, rendered_slots)
            {key, value_ir}, acc -> Map.put(acc, key, eval_ir(value_ir, a, b))
          end)

        render_component(site, component_name, component_assigns)
      else
        ""
      end
    end
  end

  # Phoenix component call with dynamic assigns (@rest spread)
  defp eval_ir({:component_call, {:component_fun, mod, fun}, {:component_assigns_dynamic, base_pairs, rest_ir}}, a, b) when is_atom(mod) and is_atom(fun) and not is_nil(mod) and not is_nil(fun) do
    # Build base assigns from static pairs (handling inner_block slots)
    component_assigns =
      Enum.reduce(base_pairs, %{}, fn
        {:__changed__, _}, acc ->
          Map.put(acc, :__changed__, nil)

        {:inner_block, {:literal, slot_irs}}, acc ->
          rendered_slots = build_cms_inner_block(slot_irs, a, b)
          Map.put(acc, :inner_block, rendered_slots)

        {key, value_ir}, acc ->
          Map.put(acc, key, eval_ir(value_ir, a, b))
      end)
      |> Map.put_new(:__changed__, nil)

    # Merge rest assigns
    rest = eval_ir(rest_ir, a, b)
    rest_map = if is_map(rest), do: rest, else: if(is_list(rest), do: Map.new(rest), else: %{})
    component_assigns = Map.merge(rest_map, component_assigns)

    apply(mod, fun, [component_assigns])
  end

  # Unresolved component with dynamic assigns — try as CMS component
  defp eval_ir({:component_call, {:component_fun, nil, fun_name}, {:component_assigns_dynamic, base_pairs, rest_ir}}, a, b) when is_atom(fun_name) do
    if function_exported?(Phoenix.Component, fun_name, 1) do
      eval_ir({:component_call, {:component_fun, Phoenix.Component, fun_name}, {:component_assigns_dynamic, base_pairs, rest_ir}}, a, b)
    else
      site = Map.get(a, :beacon, %{}) |> Map.get(:site)
      component_name = Atom.to_string(fun_name)

      if site do
        component_assigns =
          Enum.reduce(base_pairs, %{}, fn
            {:__changed__, _}, acc -> Map.put(acc, :__changed__, nil)
            {:inner_block, {:literal, slot_irs}}, acc ->
              rendered_slots = build_cms_inner_block(slot_irs, a, b)
              Map.put(acc, :inner_block, rendered_slots)
            {key, value_ir}, acc -> Map.put(acc, key, eval_ir(value_ir, a, b))
          end)

        rest = eval_ir(rest_ir, a, b)
        rest_map = if is_map(rest), do: rest, else: if(is_list(rest), do: Map.new(rest), else: %{})
        component_assigns = Map.merge(rest_map, component_assigns)

        render_component(site, component_name, component_assigns)
      else
        ""
      end
    end
  end

  defp eval_ir({:component_call, _, _}, _a, _b), do: ""

  # For body with local bindings — evaluate bindings first, then output
  defp eval_ir({:for_body_with_bindings, bind_irs, body_ir}, a, b) do
    bindings =
      Enum.reduce(bind_irs, b, fn {:bind, name, value_expr}, acc ->
        Map.put(acc, name, eval_ir(value_expr, a, acc))
      end)

    eval_ir(body_ir, a, bindings)
  end

  defp eval_ir({:interpolation, parts}, a, b) do
    parts |> Enum.map(&eval_interpolation_part(&1, a, b)) |> IO.iodata_to_binary()
  end

  defp eval_ir({:tuple, elements}, a, b) do
    List.to_tuple(Enum.map(elements, &eval_ir(&1, a, b)))
  end

  defp eval_ir({:list, elements}, a, b) do
    Enum.map(elements, &eval_ir(&1, a, b))
  end

  defp eval_ir({:map_literal, pairs}, a, b) do
    Map.new(pairs, fn
      {key, value_ir} when is_atom(key) -> {key, eval_ir(value_ir, a, b)}
      {key_ir, value_ir} -> {eval_ir(key_ir, a, b), eval_ir(value_ir, a, b)}
    end)
  end

  defp eval_ir({:access, map_ir, key_ir}, a, b) do
    Access.get(eval_ir(map_ir, a, b), eval_ir(key_ir, a, b))
  end

  defp eval_ir({:block, parts}, a, b) do
    Enum.reduce(parts, nil, fn part, _acc -> eval_ir(part, a, b) end)
  end

  # Comprehension: produces %Phoenix.LiveView.Comprehension{}
  defp eval_ir({:comprehension, %{static: static, fingerprint: fp, dynamics: dyn_expr}}, a, b) do
    dynamics = eval_comprehension_dynamics(dyn_expr, a, b)

    %Phoenix.LiveView.Comprehension{
      static: static,
      dynamics: dynamics,
      fingerprint: fp,
      stream: nil
    }
  end

  defp eval_ir({:for_expr, var_name, enum_ir, body_ir}, a, b) do
    enum = eval_ir(enum_ir, a, b)

    if is_nil(enum) or enum == "" do
      []
    else
      Enum.map(enum, fn item ->
        inner_bindings = destructure_binding(b, var_name, item)
        eval_ir(body_ir, a, inner_bindings)
      end)
    end
  end

  # Safe function calls (whitelisted modules)
  @safe_modules [String, Integer, Float, Enum, Map, List, Kernel, Phoenix.HTML, Phoenix.LiveView.HTMLEngine]
  defp eval_ir({:call, Enum, fun, args}, a, b) do
    evaluated_args = Enum.map(args, &eval_ir(&1, a, b))
    # Enum functions expect an enumerable as first arg — treat nil as empty list
    case evaluated_args do
      [nil | rest] -> apply(Enum, fun, [[] | rest])
      _ -> apply(Enum, fun, evaluated_args)
    end
  end

  # Kernel.to_string is a macro (not a runtime function), so apply/3 would crash.
  # Intercept and route through safe_to_string instead.
  defp eval_ir({:call, Kernel, :to_string, [arg]}, a, b) do
    safe_to_string(eval_ir(arg, a, b))
  end

  # String.Chars.to_string is the runtime expansion of the to_string macro
  defp eval_ir({:call, String.Chars, :to_string, [arg]}, a, b) do
    safe_to_string(eval_ir(arg, a, b))
  end

  # Kernel macros that can't be called via apply
  defp eval_ir({:call, Kernel, :<>, [left, right]}, a, b) do
    l = eval_ir(left, a, b)
    r = eval_ir(right, a, b)
    (l || "") <> (r || "")
  end

  # Map functions with nil first arg — return safe defaults
  defp eval_ir({:call, Map, fun, [map_ir | rest]}, a, b) do
    map = eval_ir(map_ir, a, b)

    if is_nil(map) do
      case {fun, length(rest)} do
        {:get, 1} -> nil
        {:get, 2} -> eval_ir(Enum.at(rest, 1), a, b)
        {:has_key?, _} -> false
        {:keys, _} -> []
        {:values, _} -> []
        _ -> nil
      end
    else
      evaluated_rest = Enum.map(rest, &eval_ir(&1, a, b))
      apply(Map, fun, [map | evaluated_rest])
    end
  end

  defp eval_ir({:call, mod, fun, args}, a, b) when mod in @safe_modules do
    evaluated_args = Enum.map(args, &eval_ir(&1, a, b))
    arity = length(evaluated_args)

    if function_exported?(mod, fun, arity) do
      apply(mod, fun, evaluated_args)
    else
      # Macro or non-existent function — use Kernel macro equivalents
      eval_kernel_macro(fun, evaluated_args)
    end
  end

  # Non-safe module calls — try as Beacon component, then allow arbitrary calls
  defp eval_ir({:call, mod, fun, args}, a, b) do
    site = Map.get(a, :beacon, %{}) |> Map.get(:site)
    component_name = Atom.to_string(fun)

    if site do
      case :ets.lookup(@table, {site, :component, component_name}) do
        [{_, _}] ->
          component_assigns =
            case args do
              [assigns_ir] ->
                raw = eval_ir(assigns_ir, a, b)
                safe_to_map(raw)

              [] ->
                %{}

              _ ->
                %{}
            end

          render_component(site, component_name, component_assigns)

        [] ->
          evaluated_args = Enum.map(args, &eval_ir(&1, a, b))
          apply(mod, fun, evaluated_args)
      end
    else
      evaluated_args = Enum.map(args, &eval_ir(&1, a, b))
      apply(mod, fun, evaluated_args)
    end
  end

  defp eval_ir({:local_call, :to_string, [arg]}, a, b) do
    safe_to_string(eval_ir(arg, a, b))
  end

  # Module alias resolution — __aliases__ resolves to a module atom
  defp eval_ir({:local_call, :__aliases__, args}, _a, _b) do
    parts =
      Enum.map(args, fn
        {:literal, v} -> v
        v when is_atom(v) -> v
        _ -> nil
      end)

    Module.concat(parts)
  end

  # Beacon component calls — render from ETS
  defp eval_ir({:local_call, :my_component, args}, a, b) do
    [name_ir | rest] = args
    name = eval_ir(name_ir, a, b)

    component_assigns =
      case rest do
        [assigns_ir] ->
          raw = eval_ir(assigns_ir, a, b)
          safe_to_map(raw)

        [] ->
          %{}
      end

    site = Map.get(a, :beacon, %{}) |> Map.get(:site)

    if site do
      render_component(site, safe_to_string(name), component_assigns)
    else
      ""
    end
  end

  # render_slot — used by components to render slot content
  # Handles: render_slot(@inner_block) and render_slot(@inner_block, arg)
  defp eval_ir({:local_call, :render_slot, args}, a, b) do
    [slot_ir | rest] = args
    slot = eval_ir(slot_ir, a, b)
    slot_arg = if rest != [], do: eval_ir(hd(rest), a, b), else: nil

    case slot do
      nil -> ""
      [] -> ""
      content when is_binary(content) -> content
      %Phoenix.LiveView.Rendered{} = rendered -> rendered
      entries when is_list(entries) ->
        # Standard Phoenix slot rendering: each entry has an :inner_block function
        results =
          Enum.map(entries, fn
            %{inner_block: inner_fn} when is_function(inner_fn, 2) ->
              inner_fn.(nil, slot_arg)
            %{inner_block: inner_fn} when is_function(inner_fn, 1) ->
              inner_fn.(slot_arg)
            other ->
              other
          end)

        # For a single slot entry, return the result directly
        # (avoids wrapping Rendered structs in a list which Phoenix.HTML.Safe can't handle)
        case results do
          [single] -> single
          multiple ->
            # Multiple slots: concatenate their string representations
            multiple
            |> Enum.map(fn
              %Phoenix.LiveView.Rendered{} = r -> r |> Phoenix.HTML.Safe.to_iodata() |> IO.iodata_to_binary()
              bin when is_binary(bin) -> bin
              other -> safe_to_string(other)
            end)
            |> IO.iodata_to_binary()
        end
      _ -> ""
    end
  end

  # Beacon helper calls — look up and execute page helpers from ETS
  defp eval_ir({:local_call, :dynamic_helper, args}, a, b) do
    [name_ir | rest] = args
    name = eval_ir(name_ir, a, b)
    helper_args = if rest != [], do: eval_ir(hd(rest), a, b), else: %{}

    site = Map.get(a, :beacon, %{}) |> Map.get(:site)
    page_id = get_in(a, [:beacon, :private, :page_id])

    if site && page_id do
      case :ets.lookup(@table, {site, page_id, :helper, name}) do
        [{_, serialized}] ->
          %{code: code_ast, args: args_pattern_ast} = :erlang.binary_to_term(serialized)

          # Match the args pattern against the provided helper_args
          case match_pattern(args_pattern_ast, helper_args, %{}) do
            {:ok, bindings} ->
              result = eval_ast(code_ast, bindings)
              safe_to_string(result)

            :no_match ->
              ""
          end

        [] ->
          ""
      end
    else
      ""
    end
  end

  # Beacon route helpers — return empty paths for now
  defp eval_ir({:local_call, :beacon_asset_path, _args}, _a, _b), do: ""
  defp eval_ir({:local_call, :beacon_asset_url, _args}, _a, _b), do: ""

  # sigil_p (Phoenix.VerifiedRoutes) — return empty for now
  defp eval_ir({:local_call, :sigil_p, _args}, _a, _b), do: ""

  defp eval_ir({:local_call, fun, args}, a, b) do
    # Try as a Beacon component first (handles <.header>, <.footer>, etc.)
    site = Map.get(a, :beacon, %{}) |> Map.get(:site)
    component_name = Atom.to_string(fun)

    if site do
      case :ets.lookup(@table, {site, :component, component_name}) do
        [{_, _}] ->
          component_assigns =
            case args do
              [assigns_ir] ->
                raw = eval_ir(assigns_ir, a, b)
                safe_to_map(raw)

              [] ->
                %{}

              _ ->
                %{}
            end

          render_component(site, component_name, component_assigns)

        [] ->
          apply_kernel_call(fun, args, a, b)
      end
    else
      apply_kernel_call(fun, args, a, b)
    end
  end

  # Safely call a Kernel function, handling macros that can't be apply'd
  defp apply_kernel_call(fun, args, a, b) do
    evaluated_args = Enum.map(args, &eval_ir(&1, a, b))
    arity = length(evaluated_args)

    if function_exported?(Kernel, fun, arity) do
      apply(Kernel, fun, evaluated_args)
    else
      # Kernel macro — provide runtime equivalents
      eval_kernel_macro(fun, evaluated_args)
    end
  end

  defp eval_kernel_macro(:is_nil, [val]), do: val == nil
  defp eval_kernel_macro(:is_atom, [val]), do: is_atom(val)
  defp eval_kernel_macro(:is_binary, [val]), do: is_binary(val)
  defp eval_kernel_macro(:is_integer, [val]), do: is_integer(val)
  defp eval_kernel_macro(:is_float, [val]), do: is_float(val)
  defp eval_kernel_macro(:is_number, [val]), do: is_number(val)
  defp eval_kernel_macro(:is_boolean, [val]), do: is_boolean(val)
  defp eval_kernel_macro(:is_list, [val]), do: is_list(val)
  defp eval_kernel_macro(:is_map, [val]), do: is_map(val)
  defp eval_kernel_macro(:is_tuple, [val]), do: is_tuple(val)
  defp eval_kernel_macro(:to_string, [val]), do: safe_to_string(val)
  defp eval_kernel_macro(:to_charlist, [val]), do: List.Chars.to_charlist(val)
  defp eval_kernel_macro(:<>, [l, r]), do: (l || "") <> (r || "")
  defp eval_kernel_macro(:and, [l, r]), do: l && r
  defp eval_kernel_macro(:or, [l, r]), do: l || r
  defp eval_kernel_macro(:in, [elem, list]), do: elem in list
  defp eval_kernel_macro(:unless, [cond, [do: body]]), do: if(!cond, do: body)
  defp eval_kernel_macro(:.., [a, b]), do: a..b
  defp eval_kernel_macro(:.., [a, b, step]), do: a..b//step
  defp eval_kernel_macro(:sigil_r, [pattern, modifiers]) do
    Regex.compile!(pattern, List.to_string(modifiers))
  end
  defp eval_kernel_macro(:sigil_w, [string, modifiers]) do
    case modifiers do
      ~c"a" -> String.split(string) |> Enum.map(&String.to_existing_atom/1)
      _ -> String.split(string)
    end
  end
  defp eval_kernel_macro(:sigil_s, [string, _modifiers]), do: string
  defp eval_kernel_macro(:sigil_S, [string, _modifiers]), do: string
  defp eval_kernel_macro(:hd, [list]), do: hd(list)
  defp eval_kernel_macro(:tl, [list]), do: tl(list)
  defp eval_kernel_macro(:length, [list]), do: length(list)
  defp eval_kernel_macro(:abs, [val]), do: abs(val)
  defp eval_kernel_macro(:min, [a, b]), do: min(a, b)
  defp eval_kernel_macro(:max, [a, b]), do: max(a, b)
  defp eval_kernel_macro(:div, [a, b]), do: div(a, b)
  defp eval_kernel_macro(:rem, [a, b]), do: rem(a, b)
  defp eval_kernel_macro(:round, [val]), do: round(val)
  defp eval_kernel_macro(:floor, [val]), do: floor(val)
  defp eval_kernel_macro(:ceil, [val]), do: ceil(val)
  defp eval_kernel_macro(:elem, [tuple, index]), do: elem(tuple, index)
  defp eval_kernel_macro(:put_elem, [tuple, index, val]), do: put_elem(tuple, index, val)
  defp eval_kernel_macro(:tuple_size, [tuple]), do: tuple_size(tuple)
  defp eval_kernel_macro(:byte_size, [binary]), do: byte_size(binary)
  defp eval_kernel_macro(:is_struct, [val]), do: is_struct(val)
  defp eval_kernel_macro(:is_struct, [val, mod]), do: is_struct(val, mod)
  defp eval_kernel_macro(:is_function, [val]), do: is_function(val)
  defp eval_kernel_macro(:is_function, [val, arity]), do: is_function(val, arity)
  defp eval_kernel_macro(:inspect, [val]), do: inspect(val)
  defp eval_kernel_macro(:inspect, [val, opts]), do: inspect(val, opts)
  defp eval_kernel_macro(:throw, [val]), do: throw(val)
  defp eval_kernel_macro(fun, args) do
    require Logger
    Logger.warning("[RuntimeRenderer] Unhandled kernel macro: #{fun}/#{length(args)}")
    nil
  end

  defp eval_comprehension_dynamics({:for_expr, var_name, enum_ir, body_ir}, a, b) do
    enum = eval_ir(enum_ir, a, b)

    if is_nil(enum) or enum == "" do
      []
    else
      Enum.map(enum, fn item ->
        inner_bindings = destructure_binding(b, var_name, item)
        result = eval_ir(body_ir, a, inner_bindings)

        case result do
          list when is_list(list) -> Enum.map(list, &safe_dynamic/1)
          single -> [safe_dynamic(single)]
        end
      end)
    end
  end

  defp eval_comprehension_dynamics(other, a, b) do
    result = eval_ir(other, a, b)

    case result do
      list when is_list(list) -> Enum.map(list, &safe_dynamic/1)
      single -> [safe_dynamic(single)]
    end
  end

  defp eval_interpolation_part({:literal, value}, _a, _b), do: value

  defp eval_interpolation_part(expr, a, b) do
    result = eval_ir(expr, a, b)

    cond do
      is_nil(result) -> ""
      is_binary(result) -> result
      is_atom(result) -> Atom.to_string(result)
      is_integer(result) -> Integer.to_string(result)
      is_float(result) -> Float.to_string(result)
      true -> String.Chars.to_string(result)
    end
  end

  defp safe_to_string(nil), do: ""
  defp safe_to_string(value) when is_binary(value), do: value
  defp safe_to_string(value) when is_atom(value), do: Atom.to_string(value)
  defp safe_to_string(value) when is_integer(value), do: Integer.to_string(value)
  defp safe_to_string(value) when is_float(value), do: Float.to_string(value)
  defp safe_to_string(value), do: String.Chars.to_string(value)

  # Converts a string to an existing atom, falling back to String.to_atom/1
  # only when the atom does not yet exist. This is safe for admin-defined keys
  # (live data keys, path params) that are bounded per-site and not derived
  # from end-user input.
  # Returns true for errors with a 4xx plug_status (client errors like 404).
  # These should not trip the circuit breaker since they're expected behavior.
  defp client_error?(%{plug_status: status}) when is_integer(status) and status >= 400 and status < 500, do: true
  defp client_error?(_), do: false

  defp safe_to_existing_atom(string) when is_binary(string) do
    String.to_existing_atom(string)
  rescue
    ArgumentError -> String.to_atom(string)
  end

  # ===========================================================================
  # Event handler AST interpreter
  # ===========================================================================
  # Evaluates parsed Elixir AST for event handlers without Code.eval.
  # Supports the common patterns used in Beacon event handlers.

  defp eval_ast({:__block__, _, exprs}, bindings) do
    exprs
    |> Enum.reduce({nil, bindings}, fn expr, {_result, acc_bindings} ->
      eval_ast_with_bindings(expr, acc_bindings)
    end)
    |> elem(0)
  end

  # Tuple: {:noreply, socket}
  defp eval_ast({:{}, _, elements}, bindings) do
    List.to_tuple(Enum.map(elements, &eval_ast(&1, bindings)))
  end

  # Two-element tuple special form
  defp eval_ast({left, right}, bindings) when not is_list(right) do
    {eval_ast(left, bindings), eval_ast(right, bindings)}
  end

  # Module alias resolution: {:__aliases__, _, [:Foo, :Bar]} → Foo.Bar
  defp eval_ast({:__aliases__, _, mod_parts}, _bindings) do
    Module.concat(mod_parts)
  end

  # raise/1 and raise/2
  defp eval_ast({:raise, _, [expr]}, bindings) do
    error = eval_ast(expr, bindings)
    raise error
  end

  defp eval_ast({:raise, _, [module_ast, opts_ast]}, bindings) do
    module = eval_ast(module_ast, bindings)
    opts = eval_ast(opts_ast, bindings)
    raise module, opts
  end

  # Variable reference
  defp eval_ast({name, _, nil}, bindings) when is_atom(name) do
    Map.get(bindings, name)
  end

  defp eval_ast({name, _, ctx}, bindings) when is_atom(name) and is_atom(ctx) do
    Map.get(bindings, name)
  end

  # Function call: assign(socket, key, value)
  defp eval_ast({:assign, _, [socket_ast, key_ast, value_ast]}, bindings) do
    socket = eval_ast(socket_ast, bindings)
    key = eval_ast(key_ast, bindings)
    value = eval_ast(value_ast, bindings)
    Phoenix.Component.assign(socket, key, value)
  end

  # Function call: assign(socket, keyword_or_map)
  defp eval_ast({:assign, _, [socket_ast, assigns_ast]}, bindings) do
    socket = eval_ast(socket_ast, bindings)
    assigns = eval_ast(assigns_ast, bindings)
    Phoenix.Component.assign(socket, assigns)
  end

  # Module-qualified function call: Module.func(args) — via __aliases__
  defp eval_ast({{:., _, [{:__aliases__, _, mod_parts}, fun]}, _, args}, bindings) when is_atom(fun) do
    module = Module.concat(mod_parts)
    evaluated_args = Enum.map(args, &eval_ast(&1, bindings))
    apply(module, fun, evaluated_args)
  end

  # Module-qualified function call: Module.func(args) — direct atom module (e.g., Kernel.to_string)
  defp eval_ast({{:., _, [module, fun]}, _, args}, bindings) when is_atom(module) and is_atom(fun) do
    evaluated_args = Enum.map(args, &eval_ast(&1, bindings))

    if function_exported?(module, fun, length(evaluated_args)) do
      apply(module, fun, evaluated_args)
    else
      eval_kernel_macro(fun, evaluated_args)
    end
  end

  # Map access: map["key"]
  defp eval_ast({{:., _, [Access, :get]}, _, [map_ast, key_ast]}, bindings) do
    map = eval_ast(map_ast, bindings)
    key = eval_ast(key_ast, bindings)
    Access.get(map, key)
  end

  # Dot access: struct.field
  defp eval_ast({{:., _, [inner, key]}, _, []}, bindings) when is_atom(key) do
    get_in(eval_ast(inner, bindings), [Access.key(key)])
  end

  # Kernel.to_string / string interpolation
  defp eval_ast({:<<>>, _, parts}, bindings) do
    parts
    |> Enum.map(fn
      {:"::", _, [expr, {:binary, _, _}]} ->
        safe_to_string(eval_ast(expr, bindings))

      binary when is_binary(binary) ->
        binary
    end)
    |> IO.iodata_to_binary()
  end

  # Map/keyword access: map[:key]
  defp eval_ast({{:., _, [{name, _, _}, key]}, _, []}, bindings) when is_atom(name) and is_atom(key) do
    get_in(bindings, [name, Access.key(key)])
  end

  # Operators
  defp eval_ast({:+, _, [l, r]}, b), do: eval_ast(l, b) + eval_ast(r, b)
  defp eval_ast({:-, _, [l, r]}, b), do: eval_ast(l, b) - eval_ast(r, b)
  defp eval_ast({:*, _, [l, r]}, b), do: eval_ast(l, b) * eval_ast(r, b)
  defp eval_ast({:/, _, [l, r]}, b), do: eval_ast(l, b) / eval_ast(r, b)
  defp eval_ast({:==, _, [l, r]}, b), do: eval_ast(l, b) == eval_ast(r, b)
  defp eval_ast({:!=, _, [l, r]}, b), do: eval_ast(l, b) != eval_ast(r, b)
  defp eval_ast({:<, _, [l, r]}, b), do: eval_ast(l, b) < eval_ast(r, b)
  defp eval_ast({:>, _, [l, r]}, b), do: eval_ast(l, b) > eval_ast(r, b)
  defp eval_ast({:<=, _, [l, r]}, b), do: eval_ast(l, b) <= eval_ast(r, b)
  defp eval_ast({:>=, _, [l, r]}, b), do: eval_ast(l, b) >= eval_ast(r, b)
  defp eval_ast({:||, _, [l, r]}, b), do: eval_ast(l, b) || eval_ast(r, b)
  defp eval_ast({:&&, _, [l, r]}, b), do: eval_ast(l, b) && eval_ast(r, b)
  defp eval_ast({:and, _, [l, r]}, b), do: eval_ast(l, b) && eval_ast(r, b)
  defp eval_ast({:or, _, [l, r]}, b), do: eval_ast(l, b) || eval_ast(r, b)
  defp eval_ast({:not, _, [expr]}, b), do: !eval_ast(expr, b)
  defp eval_ast({:!, _, [expr]}, b), do: !eval_ast(expr, b)
  defp eval_ast({:-, _, [expr]}, b), do: -eval_ast(expr, b)
  defp eval_ast({:=~, _, [l, r]}, b), do: eval_ast(l, b) =~ eval_ast(r, b)

  # Conditionals
  defp eval_ast({:if, _, [condition, clauses]}, bindings) do
    if eval_ast(condition, bindings) do
      eval_ast(Keyword.fetch!(clauses, :do), bindings)
    else
      eval_ast(Keyword.get(clauses, :else), bindings)
    end
  end

  # Anonymous function capture placeholders (&1, &2, ...)
  defp eval_ast({:&, _, [index]}, bindings) when is_integer(index) do
    Map.get(bindings, {:capture, index})
  end

  # Function capture: &Map.put(&1, key, value)
  defp eval_ast({:&, _, [expr]}, bindings) do
    arity = capture_arity(expr)

    build_runtime_function(arity, fn args ->
      capture_bindings =
        Enum.with_index(args, 1)
        |> Enum.reduce(bindings, fn {value, index}, acc ->
          Map.put(acc, {:capture, index}, value)
        end)

      eval_ast(expr, capture_bindings)
    end)
  end

  # Anonymous functions: fn value -> ... end
  defp eval_ast({:fn, _, clauses}, bindings) do
    arity = fn_arity!(clauses)

    build_runtime_function(arity, fn args ->
      eval_fn_clauses(clauses, args, bindings)
    end)
  end

  # Literals
  defp eval_ast(value, _) when is_binary(value), do: value
  defp eval_ast(value, _) when is_integer(value), do: value
  defp eval_ast(value, _) when is_float(value), do: value
  defp eval_ast(value, _) when is_boolean(value), do: value
  defp eval_ast(nil, _), do: nil
  defp eval_ast(value, _) when is_atom(value), do: value

  # Map update: %{map | key: value}
  defp eval_ast({:%{}, _, [{:|, _, [map_ast, pairs]}]}, bindings) do
    map = eval_ast(map_ast, bindings)
    updates = Map.new(pairs, fn {k, v} -> {eval_ast(k, bindings), eval_ast(v, bindings)} end)
    Map.merge(map, updates)
  end

  # Map literal: %{key => value}
  defp eval_ast({:%{}, _, pairs}, bindings) do
    Map.new(pairs, fn {k, v} -> {eval_ast(k, bindings), eval_ast(v, bindings)} end)
  end

  # Pipe operator
  defp eval_ast({:|>, _, [left, right]}, bindings) do
    left_val = eval_ast(left, bindings)

    case right do
      {{:., _, [{:__aliases__, _, mod_parts}, fun]}, _, args} ->
        module = Module.concat(mod_parts)
        evaluated_args = Enum.map(args, &eval_ast(&1, bindings))
        apply(module, fun, [left_val | evaluated_args])

      {fun, _, args} when is_atom(fun) and is_list(args) ->
        evaluated_args = Enum.map(args, &eval_ast(&1, bindings))
        arity = length(evaluated_args) + 1

        cond do
          fun == :assign and arity in [2, 3] ->
            apply(Phoenix.Component, :assign, [left_val | evaluated_args])
          fun == :put_flash and arity == 3 ->
            apply(Phoenix.LiveView, :put_flash, [left_val | evaluated_args])
          fun == :push_event and arity == 3 ->
            apply(Phoenix.LiveView, :push_event, [left_val | evaluated_args])
          fun == :redirect and arity == 2 ->
            apply(Phoenix.LiveView, :redirect, [left_val | evaluated_args])
          fun == :push_navigate and arity == 2 ->
            apply(Phoenix.LiveView, :push_navigate, [left_val | evaluated_args])
          function_exported?(Kernel, fun, arity) ->
            apply(Kernel, fun, [left_val | evaluated_args])
          true ->
            raise "unsupported pipe target: #{fun}/#{arity}"
        end

      _ ->
        raise "unsupported pipe target: #{inspect(right)}"
    end
  end

  # cond expression
  defp eval_ast({:cond, _, [[do: clauses]]}, bindings) do
    Enum.find_value(clauses, fn {:->, _, [[condition], body]} ->
      if eval_ast(condition, bindings), do: eval_ast(body, bindings)
    end)
  end

  # unless expression
  defp eval_ast({:unless, _, [condition, clauses]}, bindings) do
    unless eval_ast(condition, bindings) do
      eval_ast(Keyword.fetch!(clauses, :do), bindings)
    else
      eval_ast(Keyword.get(clauses, :else), bindings)
    end
  end

  # with expression
  defp eval_ast({:with, _, clauses_and_body}, bindings) do
    {body_opts, match_clauses} = List.pop_at(clauses_and_body, -1)
    do_body = Keyword.fetch!(body_opts, :do)
    else_clauses = Keyword.get(body_opts, :else)

    result =
      Enum.reduce_while(match_clauses, {:ok, bindings}, fn
        {:<-, _, [pattern, expr]}, {:ok, acc_bindings} ->
          value = eval_ast(expr, acc_bindings)

          case match_pattern(pattern, value, acc_bindings) do
            {:ok, new_bindings} -> {:cont, {:ok, new_bindings}}
            :no_match -> {:halt, {:error, value}}
          end
      end)

    case result do
      {:ok, final_bindings} ->
        eval_ast(do_body, final_bindings)

      {:error, unmatched} when is_list(else_clauses) ->
        Enum.find_value(else_clauses, fn {:->, _, [[pattern], body]} ->
          case match_pattern(pattern, unmatched, bindings) do
            {:ok, new_bindings} -> eval_ast(body, new_bindings)
            :no_match -> nil
          end
        end)

      {:error, _} ->
        nil
    end
  end

  # try/rescue
  defp eval_ast({:try, _, [[do: do_body] ++ rest]}, bindings) do
    rescue_clauses = Keyword.get(rest, :rescue, [])
    after_body = Keyword.get(rest, :after)

    try do
      eval_ast(do_body, bindings)
    rescue
      error ->
        matched =
          Enum.find_value(rescue_clauses, fn {:->, _, [[pattern], body]} ->
            case match_pattern(pattern, error, bindings) do
              {:ok, new_bindings} -> eval_ast(body, new_bindings)
              :no_match -> nil
            end
          end)

        matched || reraise error, __STACKTRACE__
    after
      if after_body, do: eval_ast(after_body, bindings)
    end
  end

  # for comprehension
  defp eval_ast({:for, _, args}, bindings) do
    {opts, generators} = List.pop_at(args, -1)
    do_body = Keyword.fetch!(opts, :do)

    eval_for_generators(generators, bindings, fn final_bindings ->
      eval_ast(do_body, final_bindings)
    end)
  end

  # Struct creation: %Module{field: value}
  defp eval_ast({:%, _, [module_ast, {:%{}, _, pairs}]}, bindings) do
    module = eval_ast(module_ast, bindings)
    fields = Map.new(pairs, fn {k, v} -> {eval_ast(k, bindings), eval_ast(v, bindings)} end)
    struct(module, fields)
  end

  # case expression (with optional guard support)
  defp eval_ast({:case, _, [expr, [do: clauses]]}, bindings) do
    value = eval_ast(expr, bindings)

    Enum.find_value(clauses, fn {:->, _, [[pattern_or_guard], body]} ->
      {pattern, guard} = extract_guard(pattern_or_guard)

      case match_pattern(pattern, value, bindings) do
        {:ok, new_bindings} ->
          if guard == nil or eval_ast(guard, new_bindings) do
            eval_ast(body, new_bindings)
          end

        :no_match ->
          nil
      end
    end)
  end

  # Assignment
  defp eval_ast({:=, _, [pattern, value_ast]}, bindings) do
    value = eval_ast(value_ast, bindings)

    case match_pattern(pattern, value, bindings) do
      {:ok, _new_bindings} -> value
      :no_match -> raise MatchError, term: value
    end
  end

  # Bare function call (local)
  defp eval_ast({fun, _, args}, bindings) when is_atom(fun) and is_list(args) do
    evaluated_args = Enum.map(args, &eval_ast(&1, bindings))
    arity = length(evaluated_args)

    if function_exported?(Kernel, fun, arity) do
      apply(Kernel, fun, evaluated_args)
    else
      eval_kernel_macro(fun, evaluated_args)
    end
  end

  # Keyword/map literal
  defp eval_ast(list, bindings) when is_list(list) do
    Enum.map(list, fn
      {key, value} -> {eval_ast(key, bindings), eval_ast(value, bindings)}
      value -> eval_ast(value, bindings)
    end)
  end

  defp eval_ast_with_bindings({:=, _, [pattern, value_ast]}, bindings) do
    value = eval_ast(value_ast, bindings)

    case match_pattern(pattern, value, bindings) do
      {:ok, new_bindings} -> {value, new_bindings}
      :no_match -> raise MatchError, term: value
    end
  end

  defp eval_ast_with_bindings(expr, bindings), do: {eval_ast(expr, bindings), bindings}

  defp build_runtime_function(0, evaluator), do: fn -> evaluator.([]) end
  defp build_runtime_function(1, evaluator), do: fn arg1 -> evaluator.([arg1]) end
  defp build_runtime_function(2, evaluator), do: fn arg1, arg2 -> evaluator.([arg1, arg2]) end
  defp build_runtime_function(3, evaluator), do: fn arg1, arg2, arg3 -> evaluator.([arg1, arg2, arg3]) end
  defp build_runtime_function(arity, _evaluator), do: raise(ArgumentError, "unsupported anonymous function arity: #{arity}")

  defp capture_arity(ast) do
    ast
    |> Macro.prewalk(0, fn
      {:&, _, [index]} = node, acc when is_integer(index) -> {node, max(acc, index)}
      node, acc -> {node, acc}
    end)
    |> elem(1)
  end

  defp fn_arity!([{:->, _, [patterns, _body]} | _rest]), do: length(patterns)
  defp fn_arity!(_), do: raise(ArgumentError, "anonymous functions must define at least one clause")

  defp eval_fn_clauses(clauses, args, bindings) do
    Enum.find_value(clauses, fn
      {:->, _, [patterns, body]} ->
        {bare_patterns, guard} = extract_fn_guard(patterns)

        if length(bare_patterns) == length(args) do
          case bind_patterns(bare_patterns, args, bindings) do
            {:ok, clause_bindings} ->
              if guard == nil or eval_ast(guard, clause_bindings) do
                {:matched, eval_ast(body, clause_bindings)}
              end

            :no_match ->
              nil
          end
        end

      _ ->
        nil
    end)
    |> case do
      {:matched, value} -> value
      nil -> raise FunctionClauseError, "no anonymous function clause matched #{inspect(args)}"
    end
  end

  defp bind_patterns(patterns, args, bindings) do
    Enum.zip(patterns, args)
    |> Enum.reduce_while({:ok, bindings}, fn {pattern, value}, {:ok, acc} ->
      case match_pattern(pattern, value, acc) do
        {:ok, new_acc} -> {:cont, {:ok, new_acc}}
        :no_match -> {:halt, :no_match}
      end
    end)
  end

  # Pattern matching for case clauses
  defp match_pattern({:_, _, _}, _value, bindings), do: {:ok, bindings}

  defp match_pattern({name, _, nil}, value, bindings) when is_atom(name) do
    {:ok, Map.put(bindings, name, value)}
  end

  defp match_pattern({name, _, ctx}, value, bindings) when is_atom(name) and is_atom(ctx) do
    {:ok, Map.put(bindings, name, value)}
  end

  defp match_pattern(literal, value, bindings) when is_binary(literal) do
    if literal == value, do: {:ok, bindings}, else: :no_match
  end

  defp match_pattern(literal, value, bindings) when is_atom(literal) do
    if literal == value, do: {:ok, bindings}, else: :no_match
  end

  defp match_pattern(literal, value, bindings) when is_integer(literal) do
    if literal == value, do: {:ok, bindings}, else: :no_match
  end

  # Keyword pattern like [ok: pattern]
  defp match_pattern([{key, inner_pattern}], value, bindings) when is_atom(key) do
    case value do
      {^key, inner_value} -> match_pattern(inner_pattern, inner_value, bindings)
      _ -> :no_match
    end
  end

  # Tuple pattern like {left, right}
  defp match_pattern({left_pattern, right_pattern}, value, bindings) when is_tuple(value) and tuple_size(value) == 2 do
    match_pattern_sequence([left_pattern, right_pattern], Tuple.to_list(value), bindings)
  end

  # Tuple pattern AST like {a, b, c}
  defp match_pattern({:{}, _, patterns}, value, bindings) when is_tuple(value) do
    if tuple_size(value) == length(patterns) do
      match_pattern_sequence(patterns, Tuple.to_list(value), bindings)
    else
      :no_match
    end
  end

  # List pattern like [head | tail] or [a, b | tail]
  defp match_pattern(patterns, value, bindings) when is_list(patterns) and is_list(value) do
    match_list_pattern(patterns, value, bindings)
  end

  # Map/struct pattern like %{name: name}
  defp match_pattern({:%{}, _, pairs}, value, bindings) when is_map(value) do
    Enum.reduce_while(pairs, {:ok, bindings}, fn {k, v_pattern}, {:ok, acc} ->
      key = if is_atom(k), do: k, else: eval_ast(k, acc)

      case Map.fetch(value, key) do
        {:ok, v} ->
          case match_pattern(v_pattern, v, acc) do
            {:ok, new_acc} -> {:cont, {:ok, new_acc}}
            :no_match -> {:halt, :no_match}
          end

        :error ->
          {:halt, :no_match}
      end
    end)
  end

  # Pin operator: ^variable — match against existing binding value
  defp match_pattern({:^, _, [{name, _, _}]}, value, bindings) when is_atom(name) do
    case Map.fetch(bindings, name) do
      {:ok, ^value} -> {:ok, bindings}
      _ -> :no_match
    end
  end

  # Bind pattern: left_pattern = right_pattern (e.g., %Post{} = post)
  defp match_pattern({:=, _, [left, right]}, value, bindings) do
    case match_pattern(left, value, bindings) do
      {:ok, bindings2} -> match_pattern(right, value, bindings2)
      :no_match -> :no_match
    end
  end

  # Struct pattern: %Module{key: pattern, ...}
  defp match_pattern({:%, _, [module_ast, {:%{}, _, pairs}]}, value, bindings) when is_map(value) do
    module = eval_ast(module_ast, bindings)

    if is_struct(value, module) do
      # Delegate to map pattern matching for the fields
      match_pattern({:%{}, [], pairs}, value, bindings)
    else
      :no_match
    end
  end

  defp match_pattern(_, _, _), do: :no_match

  defp match_pattern_sequence(patterns, values, bindings) when length(patterns) == length(values) do
    Enum.zip(patterns, values)
    |> Enum.reduce_while({:ok, bindings}, fn {pattern, value}, {:ok, acc} ->
      case match_pattern(pattern, value, acc) do
        {:ok, new_acc} -> {:cont, {:ok, new_acc}}
        :no_match -> {:halt, :no_match}
      end
    end)
  end

  defp match_pattern_sequence(_patterns, _values, _bindings), do: :no_match

  defp match_list_pattern([], [], bindings), do: {:ok, bindings}
  defp match_list_pattern([], _values, _bindings), do: :no_match
  defp match_list_pattern(_patterns, [], _bindings), do: :no_match

  defp match_list_pattern([{:|, _, [head_pattern, tail_pattern]}], [head_value | tail_values], bindings) do
    with {:ok, head_bindings} <- match_pattern(head_pattern, head_value, bindings),
         {:ok, tail_bindings} <- match_pattern(tail_pattern, tail_values, head_bindings) do
      {:ok, tail_bindings}
    else
      :no_match -> :no_match
    end
  end

  defp match_list_pattern([head_pattern | tail_patterns], [head_value | tail_values], bindings) do
    with {:ok, head_bindings} <- match_pattern(head_pattern, head_value, bindings) do
      match_list_pattern(tail_patterns, tail_values, head_bindings)
    end
  end

  # Extract guard from case pattern: {:when, _, [pattern, guard]}
  defp extract_guard({:when, _, [pattern, guard]}), do: {pattern, guard}
  defp extract_guard(pattern), do: {pattern, nil}

  # Extract guard from fn clause patterns: [pattern, {:when, _, guard}] or [{:when, _, [pattern, guard]}]
  defp extract_fn_guard([{:when, _, clauses}]) do
    {patterns, [guard]} = Enum.split(clauses, -1)
    {patterns, guard}
  end

  defp extract_fn_guard(patterns), do: {patterns, nil}

  # Evaluate for comprehension generators recursively
  defp eval_for_generators([], bindings, body_fn) do
    [body_fn.(bindings)]
  end

  defp eval_for_generators([{:<-, _, [pattern, enum_ast]} | rest], bindings, body_fn) do
    enum = eval_ast(enum_ast, bindings)

    Enum.flat_map(enum, fn item ->
      case match_pattern(pattern, item, bindings) do
        {:ok, new_bindings} -> eval_for_generators(rest, new_bindings, body_fn)
        :no_match -> []
      end
    end)
  end

  # Filter clause in for comprehension
  defp eval_for_generators([filter_ast | rest], bindings, body_fn) do
    if eval_ast(filter_ast, bindings) do
      eval_for_generators(rest, bindings, body_fn)
    else
      []
    end
  end
end
