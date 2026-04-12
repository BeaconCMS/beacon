defmodule Beacon.Template.Parser do
  @moduledoc """
  Parses Beacon template syntax into a platform-agnostic JSON AST.

  Templates are HTML with `{{ }}` interpolation and `:directive` attributes:

      <h1>{{ post.title }}</h1>
      <div :if="post.featured" class="badge">Featured</div>
      <ul :for="item in items"><li>{{ item.name }}</li></ul>

  The parser uses Floki for HTML parsing, then walks the tree to identify
  directives, interpolations, and event bindings.
  """

  alias Beacon.Template.AST
  alias Beacon.Template.ExpressionParser

  @directives ~w(if else-if else for)
  @interpolation_regex ~r/\{\{(.+?)\}\}/s

  @doc """
  Parse a Beacon template string into a list of AST nodes.
  """
  @spec parse(binary()) :: [AST.node()]
  def parse(template) when is_binary(template) do
    # Pre-process: protect {{ }} from Floki's HTML parser by wrapping
    # them in a placeholder element that Floki won't modify
    protected = protect_interpolations(template)

    # Parse HTML with Floki
    case Floki.parse_fragment(protected) do
      {:ok, tree} ->
        tree
        |> Enum.flat_map(&convert_node/1)
        |> link_else_chains()

      {:error, reason} ->
        raise Beacon.Template.ParseError, "HTML parse error: #{inspect(reason)}"
    end
  end

  # Protect {{ }} interpolations by replacing them with placeholder elements
  # that Floki treats as text. We use a marker that won't appear in normal content.
  @placeholder_prefix "BEACON_EXPR_"
  @placeholder_suffix "_EXPR_BEACON"

  defp protect_interpolations(template) do
    {result, _counter} =
      Regex.scan(@interpolation_regex, template, return: :index)
      |> Enum.reduce({template, 0}, fn [{start, len} | _], {tmpl, offset} ->
        expr_content = String.slice(template, start + 2, len - 4) |> String.trim()
        placeholder = "#{@placeholder_prefix}#{Base.encode64(expr_content)}#{@placeholder_suffix}"
        before = String.slice(tmpl, 0, start + offset)
        after_ = String.slice(tmpl, start + offset + len, String.length(tmpl))
        {before <> placeholder <> after_, offset + String.length(placeholder) - len}
      end)

    result
  end

  defp restore_interpolation(text) do
    Regex.replace(
      ~r/#{@placeholder_prefix}(.+?)#{@placeholder_suffix}/,
      text,
      fn _, encoded ->
        expr = Base.decode64!(encoded)
        "{{#{expr}}}"
      end
    )
  end

  # Convert a Floki node to AST node(s)
  defp convert_node({:comment, _content}), do: []

  defp convert_node(text) when is_binary(text) do
    text = restore_interpolation(text)
    parse_text_with_interpolations(text)
  end

  defp convert_node({"template", attrs, children}) do
    attrs_map = Map.new(attrs)

    cond do
      Map.has_key?(attrs_map, ":if") ->
        condition = ExpressionParser.parse_condition(attrs_map[":if"])
        then_nodes = Enum.flat_map(children, &convert_node/1)
        [AST.conditional(condition, [AST.fragment(then_nodes)])]

      Map.has_key?(attrs_map, ":for") ->
        {iterator, iterable} = ExpressionParser.parse_for(attrs_map[":for"])
        body = Enum.flat_map(children, &convert_node/1)
        [AST.loop(iterator, iterable, [AST.fragment(body)])]

      true ->
        # Plain <template> — just render children as fragment
        children_ast = Enum.flat_map(children, &convert_node/1)
        [AST.fragment(children_ast)]
    end
  end

  defp convert_node({tag, attrs, children}) do
    attrs_map = Map.new(attrs)
    children_ast = Enum.flat_map(children, &convert_node/1)

    cond do
      Map.has_key?(attrs_map, ":if") ->
        condition = ExpressionParser.parse_condition(attrs_map[":if"])
        rest_attrs = Map.drop(attrs_map, [":if"])
        element = build_element(tag, rest_attrs, children_ast)
        [AST.conditional(condition, [element])]

      Map.has_key?(attrs_map, ":else-if") ->
        condition = ExpressionParser.parse_condition(attrs_map[":else-if"])
        rest_attrs = Map.drop(attrs_map, [":else-if"])
        element = build_element(tag, rest_attrs, children_ast)
        [{:pending_else_if, condition, [element]}]

      Map.has_key?(attrs_map, ":else") ->
        rest_attrs = Map.drop(attrs_map, [":else"])
        element = build_element(tag, rest_attrs, children_ast)
        [{:pending_else, [element]}]

      Map.has_key?(attrs_map, ":for") ->
        {iterator, iterable} = ExpressionParser.parse_for(attrs_map[":for"])
        rest_attrs = Map.drop(attrs_map, [":for"])
        element = build_element(tag, rest_attrs, children_ast)
        [AST.loop(iterator, iterable, [element])]

      true ->
        [build_element(tag, attrs_map, children_ast)]
    end
  end

  defp convert_node(_), do: []

  defp build_element(tag, attrs_map, children) do
    {static_attrs, dynamic_attrs, events} = classify_attrs(attrs_map)

    # Merge dynamic attrs into static attrs map
    all_attrs =
      Map.merge(
        static_attrs,
        Map.new(dynamic_attrs, fn {name, expr} ->
          {name, ExpressionParser.parse_interpolation(expr)}
        end)
      )

    AST.element(tag, all_attrs, events, children)
  end

  defp classify_attrs(attrs_map) do
    Enum.reduce(attrs_map, {%{}, %{}, %{}}, fn
      {":" <> directive, _value}, acc when directive in @directives ->
        # Already handled at the node level
        acc

      {":" <> prop_name, value}, {static, dynamic, events} ->
        {static, Map.put(dynamic, prop_name, value), events}

      {"@" <> event_name, handler}, {static, dynamic, events} ->
        {static, dynamic, Map.put(events, event_name, handler)}

      {name, value}, {static, dynamic, events} ->
        {Map.put(static, name, restore_interpolation(value)), dynamic, events}
    end)
  end

  defp extract_directive_attrs(attrs_map) do
    directive_keys = Enum.filter(Map.keys(attrs_map), &String.starts_with?(&1, ":"))
    rest = Map.drop(attrs_map, directive_keys)
    {Map.take(attrs_map, directive_keys), rest}
  end

  # Parse text content, splitting on {{ }} interpolations
  defp parse_text_with_interpolations(text) do
    parts = Regex.split(@interpolation_regex, text, include_captures: true)

    parts
    |> Enum.flat_map(fn part ->
      case Regex.run(@interpolation_regex, part) do
        [_, expr] ->
          parsed = ExpressionParser.parse_interpolation(String.trim(expr))
          [%{type: :expression, path: parsed.path, filters: parsed.filters}]

        nil ->
          if part == "", do: [], else: [AST.text(part)]
      end
    end)
  end

  # Link :else and :else-if to the preceding :if conditional
  defp link_else_chains(nodes) do
    nodes
    |> Enum.reduce([], fn
      {:pending_else_if, condition, then_nodes}, acc ->
        case acc do
          [%{type: :conditional} = prev | rest] ->
            updated = append_else_if(prev, condition, then_nodes)
            [updated | rest]

          _ ->
            raise Beacon.Template.ParseError, ":else-if without preceding :if"
        end

      {:pending_else, else_nodes}, acc ->
        case acc do
          [%{type: :conditional} = prev | rest] ->
            updated = append_else(prev, else_nodes)
            [updated | rest]

          _ ->
            raise Beacon.Template.ParseError, ":else without preceding :if"
        end

      node, acc ->
        # Recursively link else chains in children
        node = link_children(node)
        [node | acc]
    end)
    |> Enum.reverse()
  end

  defp append_else_if(conditional, condition, then_nodes) do
    if conditional.else == [] do
      %{conditional | else: [AST.conditional(condition, then_nodes)]}
    else
      # Nested: append to the last else branch
      [last_else | _] = conditional.else

      if last_else.type == :conditional do
        %{conditional | else: [append_else_if(last_else, condition, then_nodes)]}
      else
        raise Beacon.Template.ParseError, ":else-if after :else"
      end
    end
  end

  defp append_else(conditional, else_nodes) do
    if conditional.else == [] do
      %{conditional | else: else_nodes}
    else
      [last_else | _] = conditional.else

      if last_else.type == :conditional do
        %{conditional | else: [append_else(last_else, else_nodes)]}
      else
        raise Beacon.Template.ParseError, "duplicate :else"
      end
    end
  end

  defp link_children(%{children: children} = node) when is_list(children) do
    %{node | children: link_else_chains(children)}
  end

  defp link_children(%{then: then_nodes, else: else_nodes} = node) do
    %{node | then: link_else_chains(then_nodes), else: link_else_chains(else_nodes)}
  end

  defp link_children(node), do: node
end
