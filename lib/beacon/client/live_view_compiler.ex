defmodule Beacon.Client.LiveViewCompiler do
  @moduledoc """
  Compiles a platform-agnostic JSON AST into Phoenix LiveView `%Rendered{}` structs.

  This is the LiveView-specific client compiler. It walks the AST and produces
  `%Phoenix.LiveView.Rendered{}` with proper static/dynamic splitting for
  efficient LiveView diffs.
  """

  alias Beacon.Client.Filters

  @doc """
  Render an AST node list with the given assigns into a `%Phoenix.LiveView.Rendered{}`.
  """
  @spec render([map()], map()) :: Phoenix.LiveView.Rendered.t()
  def render(ast, assigns) when is_list(ast) do
    iodata = render_nodes(ast, assigns)

    %Phoenix.LiveView.Rendered{
      static: [IO.iodata_to_binary(iodata)],
      dynamic: fn _ -> [] end,
      fingerprint: :erlang.phash2(ast),
      root: true,
      caller: :not_available
    }
  end

  @doc """
  Render AST nodes to an iodata list (for embedding in other rendered output).
  """
  @spec render_to_iodata([map()], map()) :: iodata()
  def render_to_iodata(ast, assigns) when is_list(ast) do
    render_nodes(ast, assigns)
  end

  @doc """
  Render AST nodes to an HTML string.
  """
  @spec render_to_string([map()], map()) :: binary()
  def render_to_string(ast, assigns) when is_list(ast) do
    ast |> render_nodes(assigns) |> IO.iodata_to_binary()
  end

  # -- Node rendering --

  defp render_nodes(nodes, assigns) do
    Enum.map(nodes, &render_node(&1, assigns))
  end

  defp render_node(%{"type" => "text", "value" => value}, _assigns) do
    html_escape(value)
  end

  defp render_node(%{type: :text, value: value}, _assigns) do
    html_escape(value)
  end

  defp render_node(%{"type" => "expression"} = node, assigns) do
    path = node["path"]
    filters = node["filters"] || []
    value = resolve_path(path, assigns)
    value = apply_filters(value, filters)
    html_escape(to_display_string(value))
  end

  defp render_node(%{type: :expression} = node, assigns) do
    value = resolve_path(node.path, assigns)
    value = apply_filters(value, node.filters || [])
    html_escape(to_display_string(value))
  end

  defp render_node(%{"type" => "element"} = node, assigns) do
    tag = node["tag"]
    attrs = render_attrs(node["attrs"] || %{}, assigns)
    events = render_events(node["events"] || %{})
    children = render_nodes(node["children"] || [], assigns)

    if self_closing?(tag) do
      ["<", tag, attrs, events, "/>"]
    else
      ["<", tag, attrs, events, ">", children, "</", tag, ">"]
    end
  end

  defp render_node(%{type: :element} = node, assigns) do
    tag = node.tag
    attrs = render_attrs(node.attrs || %{}, assigns)
    events = render_events(node.events || %{})
    children = render_nodes(node.children || [], assigns)

    if self_closing?(tag) do
      ["<", tag, attrs, events, "/>"]
    else
      ["<", tag, attrs, events, ">", children, "</", tag, ">"]
    end
  end

  defp render_node(%{"type" => "conditional"} = node, assigns) do
    if evaluate_test(node["test"], assigns) do
      render_nodes(node["then"] || [], assigns)
    else
      render_nodes(node["else"] || [], assigns)
    end
  end

  defp render_node(%{type: :conditional} = node, assigns) do
    if evaluate_test(node.test, assigns) do
      render_nodes(node.then || [], assigns)
    else
      render_nodes(node.else || [], assigns)
    end
  end

  defp render_node(%{"type" => "loop"} = node, assigns) do
    iterator = node["iterator"]
    collection = resolve_path(node["iterable"], assigns)
    children = node["children"] || []

    if is_list(collection) do
      Enum.map(collection, fn item ->
        loop_assigns = Map.put(assigns, iterator, item)
        render_nodes(children, loop_assigns)
      end)
    else
      []
    end
  end

  defp render_node(%{type: :loop} = node, assigns) do
    collection = resolve_path(node.iterable, assigns)
    children = node.children || []

    if is_list(collection) do
      Enum.map(collection, fn item ->
        loop_assigns = Map.put(assigns, node.iterator, item)
        render_nodes(children, loop_assigns)
      end)
    else
      []
    end
  end

  defp render_node(%{"type" => "fragment", "children" => children}, assigns) do
    render_nodes(children, assigns)
  end

  defp render_node(%{type: :fragment, children: children}, assigns) do
    render_nodes(children, assigns)
  end

  defp render_node(_, _assigns), do: []

  # -- Attribute rendering --

  defp render_attrs(attrs, assigns) when is_map(attrs) do
    Enum.map(attrs, fn
      {name, %{"type" => "expression"} = expr} ->
        value = resolve_path(expr["path"], assigns)
        value = apply_filters(value, expr["filters"] || [])
        [" ", name, "=\"", html_escape_attr(to_display_string(value)), "\""]

      {name, %{type: :expression} = expr} ->
        value = resolve_path(expr.path, assigns)
        value = apply_filters(value, expr.filters || [])
        [" ", name, "=\"", html_escape_attr(to_display_string(value)), "\""]

      {name, value} when is_binary(value) ->
        [" ", name, "=\"", html_escape_attr(value), "\""]

      {_name, nil} ->
        []
    end)
  end

  defp render_events(events) when is_map(events) and map_size(events) == 0, do: []

  defp render_events(events) when is_map(events) do
    Enum.map(events, fn {event, handler} ->
      # LiveView event binding: phx-click, phx-submit, etc.
      [" phx-", event, "=\"", html_escape_attr(handler), "\""]
    end)
  end

  # -- Path resolution --

  @doc """
  Resolve a dot-notation path against an assigns map.

  Supports both string and atom keys at each level:
  - `"post.title"` resolves to `assigns["post"]["title"]` or `assigns[:post][:title]`
  """
  def resolve_path(path, assigns) when is_binary(path) do
    path
    |> String.split(".")
    |> resolve_segments(assigns)
  end

  def resolve_path(_, _), do: nil

  defp resolve_segments([], value), do: value
  defp resolve_segments(_segments, nil), do: nil

  defp resolve_segments([key | rest], map) when is_map(map) do
    value =
      case Map.get(map, key) do
        nil -> Map.get(map, String.to_existing_atom(key))
        v -> v
      end
    resolve_segments(rest, value)
  rescue
    ArgumentError -> nil
  end

  defp resolve_segments(_, _), do: nil

  # -- Test evaluation --

  defp evaluate_test(%{"left" => left, "op" => op, "right" => right}, assigns) do
    left_val = evaluate_test(left, assigns)
    right_val = evaluate_test(right, assigns)

    case op do
      "and" -> left_val and right_val
      "or" -> left_val or right_val
      _ -> false
    end
  end

  defp evaluate_test(%{left: left, op: op, right: right}, assigns) do
    evaluate_test(%{"left" => left, "op" => op, "right" => right}, assigns)
  end

  defp evaluate_test(%{"path" => path, "op" => nil}, assigns) do
    truthy?(resolve_path(path, assigns))
  end

  defp evaluate_test(%{path: path, op: nil}, assigns) do
    truthy?(resolve_path(path, assigns))
  end

  defp evaluate_test(%{"path" => path, "op" => op, "value" => expected}, assigns) do
    actual = resolve_path(path, assigns)
    compare(actual, op, expected)
  end

  defp evaluate_test(%{path: path, op: op, value: expected}, assigns) do
    evaluate_test(%{"path" => path, "op" => op, "value" => expected}, assigns)
  end

  defp evaluate_test(_, _), do: false

  defp compare(actual, "==", expected), do: actual == expected
  defp compare(actual, "!=", expected), do: actual != expected
  defp compare(actual, ">", expected) when is_number(actual) and is_number(expected), do: actual > expected
  defp compare(actual, "<", expected) when is_number(actual) and is_number(expected), do: actual < expected
  defp compare(actual, ">=", expected) when is_number(actual) and is_number(expected), do: actual >= expected
  defp compare(actual, "<=", expected) when is_number(actual) and is_number(expected), do: actual <= expected
  defp compare(_, _, _), do: false

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(""), do: false
  defp truthy?([]), do: false
  defp truthy?(_), do: true

  # -- Filters --

  defp apply_filters(value, []), do: value

  defp apply_filters(value, filters) do
    Enum.reduce(filters, value, fn
      %{"name" => name, "args" => args}, acc -> Filters.apply(name, acc, args)
      %{name: name, args: args}, acc -> Filters.apply(name, acc, args)
    end)
  end

  # -- HTML escaping --

  defp html_escape(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp html_escape(other), do: to_display_string(other)

  defp html_escape_attr(text) when is_binary(text) do
    String.replace(text, "\"", "&quot;")
  end

  defp html_escape_attr(other), do: to_display_string(other)

  defp to_display_string(nil), do: ""
  defp to_display_string(value) when is_binary(value), do: value
  defp to_display_string(value) when is_integer(value), do: Integer.to_string(value)
  defp to_display_string(value) when is_float(value), do: Float.to_string(value)
  defp to_display_string(true), do: "true"
  defp to_display_string(false), do: "false"
  defp to_display_string(value) when is_atom(value), do: Atom.to_string(value)
  defp to_display_string(value), do: inspect(value)

  @self_closing_tags ~w(area base br col embed hr img input link meta param source track wbr)

  defp self_closing?(tag), do: tag in @self_closing_tags
end
