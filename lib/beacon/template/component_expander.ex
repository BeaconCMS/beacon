defmodule Beacon.Template.ComponentExpander do
  @moduledoc """
  Expands component references in a page AST into inline primitive nodes.

  At publish time, component element nodes (e.g., `<post-card :title="post.title" />`)
  are replaced with the component's own AST, with binding paths rewritten from
  component-local props to their source expressions.

  After expansion, the AST contains only primitive nodes — no component references.
  Clients never need to know about components.
  """

  @doc """
  Expand all component references in an AST.

  `component_registry` is a map of `%{"component-name" => [ast_nodes]}`.

  Repeats expansion until no component references remain (handles nested components).
  Maximum 10 passes to prevent infinite recursion from circular component references.
  """
  # Standard HTML tags that must never be treated as component references
  @html_tags ~w(
    a abbr address area article aside audio b base bdi bdo blockquote body br
    button canvas caption cite code col colgroup data datalist dd del details
    dfn dialog div dl dt em embed fieldset figcaption figure footer form
    h1 h2 h3 h4 h5 h6 head header hgroup hr html i iframe img input ins kbd
    label legend li link main map mark menu meta meter nav noscript object
    ol optgroup option output p param picture pre progress q rp rt ruby s
    samp script search section select slot small source span strong style sub
    summary sup table tbody td template textarea tfoot th thead time title
    tr track u ul var video wbr
  )

  @spec expand([map()], map()) :: [map()]
  def expand(ast, component_registry, depth \\ 0)

  def expand(_ast, _registry, depth) when depth > 10 do
    raise Beacon.Template.ParseError, "component expansion exceeded maximum depth (possible circular reference)"
  end

  def expand(ast, component_registry, depth) when is_list(ast) do
    expanded = Enum.flat_map(ast, &expand_node(&1, component_registry))

    if has_component_refs?(expanded, component_registry) do
      expand(expanded, component_registry, depth + 1)
    else
      expanded
    end
  end

  defp expand_node(%{type: :element, tag: tag} = node, registry) do
    if tag in @html_tags do
      # Standard HTML tag — never expand, just recurse into children
      [%{node | children: Enum.flat_map(node.children, &expand_node(&1, registry))}]
    else
      case Map.get(registry, tag) do
        nil ->
          # Not a component — recurse into children
          [%{node | children: Enum.flat_map(node.children, &expand_node(&1, registry))}]

        component_ast ->
          # Component found — inline it
          prop_map = build_prop_map(node.attrs)
          inlined = rewrite_bindings(component_ast, prop_map)
          inlined
      end
    end
  end

  defp expand_node(%{type: :conditional} = node, registry) do
    [%{node |
      then: Enum.flat_map(node.then, &expand_node(&1, registry)),
      else: Enum.flat_map(node.else, &expand_node(&1, registry))
    }]
  end

  defp expand_node(%{type: :loop} = node, registry) do
    [%{node | children: Enum.flat_map(node.children, &expand_node(&1, registry))}]
  end

  defp expand_node(%{type: :fragment} = node, registry) do
    [%{node | children: Enum.flat_map(node.children, &expand_node(&1, registry))}]
  end

  defp expand_node(node, _registry), do: [node]

  # Build a mapping from component prop names to source expressions.
  # Static attrs become literal values, dynamic attrs (:prop) become expressions.
  defp build_prop_map(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {name, %{type: :expression} = expr} ->
        {name, expr}

      {name, value} ->
        {name, %{type: :text, value: value}}
    end)
  end

  # Rewrite binding paths in the component's AST using the prop mapping.
  # For example, if the component uses `{{ title }}` and the prop mapping
  # has `"title" => %{type: :expression, path: "post.title"}`,
  # then `{{ title }}` becomes `{{ post.title }}`.
  defp rewrite_bindings(nodes, prop_map) when is_list(nodes) do
    Enum.map(nodes, &rewrite_node(&1, prop_map))
  end

  defp rewrite_node(%{type: :expression, path: path} = node, prop_map) do
    rewrite_path(node, path, prop_map)
  end

  defp rewrite_node(%{type: :element} = node, prop_map) do
    %{node |
      attrs: rewrite_attrs(node.attrs, prop_map),
      children: rewrite_bindings(node.children, prop_map)
    }
  end

  defp rewrite_node(%{type: :conditional} = node, prop_map) do
    %{node |
      test: rewrite_test(node.test, prop_map),
      then: rewrite_bindings(node.then, prop_map),
      else: rewrite_bindings(node.else, prop_map)
    }
  end

  defp rewrite_node(%{type: :loop} = node, prop_map) do
    iterable = rewrite_iterable(node.iterable, prop_map)

    # The iterator variable shadows any prop with the same name
    # inside the loop body, so remove it from the prop map
    inner_prop_map = Map.delete(prop_map, node.iterator)

    %{node |
      iterable: iterable,
      children: rewrite_bindings(node.children, inner_prop_map)
    }
  end

  defp rewrite_node(%{type: :fragment} = node, prop_map) do
    %{node | children: rewrite_bindings(node.children, prop_map)}
  end

  defp rewrite_node(node, _prop_map), do: node

  # Rewrite a path expression using the prop map.
  # "title" with prop "title" => "post.title" becomes "post.title"
  # "title.length" with prop "title" => "post.title" becomes "post.title.length"
  defp rewrite_path(node, path, prop_map) do
    {root, rest} = split_path(path)

    case Map.get(prop_map, root) do
      %{type: :expression, path: source_path} ->
        new_path = if rest == "", do: source_path, else: "#{source_path}.#{rest}"
        %{node | path: new_path}

      %{type: :text, value: value} ->
        # Static prop — replace expression with text
        %{type: :text, value: to_string(value)}

      nil ->
        # Not a prop reference — leave as-is (could be a loop variable)
        node
    end
  end

  defp rewrite_attrs(attrs, prop_map) when is_map(attrs) do
    Map.new(attrs, fn
      {name, %{type: :expression, path: path} = expr} ->
        {name, rewrite_path(expr, path, prop_map)}

      {name, value} ->
        {name, value}
    end)
  end

  defp rewrite_test(%{left: left, op: op, right: right}, prop_map) do
    %{left: rewrite_test(left, prop_map), op: op, right: rewrite_test(right, prop_map)}
  end

  defp rewrite_test(%{path: path} = test, prop_map) do
    {root, rest} = split_path(path)

    case Map.get(prop_map, root) do
      %{type: :expression, path: source_path} ->
        new_path = if rest == "", do: source_path, else: "#{source_path}.#{rest}"
        %{test | path: new_path}

      _ ->
        test
    end
  end

  defp rewrite_iterable(iterable, prop_map) do
    {root, rest} = split_path(iterable)

    case Map.get(prop_map, root) do
      %{type: :expression, path: source_path} ->
        if rest == "", do: source_path, else: "#{source_path}.#{rest}"

      _ ->
        iterable
    end
  end

  defp split_path(path) do
    case String.split(path, ".", parts: 2) do
      [root, rest] -> {root, rest}
      [root] -> {root, ""}
    end
  end

  defp has_component_refs?(nodes, registry) do
    Enum.any?(nodes, &node_has_component?(&1, registry))
  end

  defp node_has_component?(%{type: :element, tag: tag, children: children}, registry) do
    (tag not in @html_tags and Map.has_key?(registry, tag)) or
      Enum.any?(children, &node_has_component?(&1, registry))
  end

  defp node_has_component?(%{type: :conditional, then: then_nodes, else: else_nodes}, registry) do
    Enum.any?(then_nodes, &node_has_component?(&1, registry)) or
      Enum.any?(else_nodes, &node_has_component?(&1, registry))
  end

  defp node_has_component?(%{type: :loop, children: children}, registry) do
    Enum.any?(children, &node_has_component?(&1, registry))
  end

  defp node_has_component?(%{type: :fragment, children: children}, registry) do
    Enum.any?(children, &node_has_component?(&1, registry))
  end

  defp node_has_component?(_, _), do: false
end
