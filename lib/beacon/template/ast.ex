defmodule Beacon.Template.AST do
  @moduledoc """
  Platform-agnostic template AST node types.

  Six node types represent the entire template vocabulary:

  - `element` — HTML tag with attributes, events, and children
  - `text` — Static text content
  - `expression` — Data binding with optional filters
  - `conditional` — if/else-if/else branching
  - `loop` — Iteration over a collection
  - `fragment` — Grouping wrapper that renders no DOM element
  """

  @type ast_node ::
          element()
          | text()
          | expression()
          | conditional()
          | loop()
          | fragment()

  @type element :: %{
          type: :element,
          tag: binary(),
          attrs: %{binary() => binary() | expression_value()},
          events: %{binary() => binary()},
          children: [ast_node()]
        }

  @type text :: %{type: :text, value: binary()}

  @type expression :: %{
          type: :expression,
          path: binary(),
          filters: [filter()]
        }

  @type filter :: %{name: binary(), args: [term()]}

  @type conditional :: %{
          type: :conditional,
          test: test_expr(),
          then: [ast_node()],
          else: [ast_node()]
        }

  @type test_expr ::
          %{path: binary(), op: binary() | nil, value: term()}
          | %{left: test_expr(), op: binary(), right: test_expr()}

  @type loop :: %{
          type: :loop,
          iterator: binary(),
          iterable: binary(),
          children: [ast_node()]
        }

  @type fragment :: %{type: :fragment, children: [ast_node()]}

  @type expression_value :: %{type: :expression, path: binary(), filters: [filter()]}

  # Constructors

  def element(tag, attrs \\ %{}, events \\ %{}, children \\ []) do
    %{type: :element, tag: tag, attrs: attrs, events: events, children: children}
  end

  def text(value), do: %{type: :text, value: value}

  def expression(path, filters \\ []) do
    %{type: :expression, path: path, filters: filters}
  end

  def conditional(test, then_nodes, else_nodes \\ []) do
    %{type: :conditional, test: test, then: then_nodes, else: else_nodes}
  end

  def loop(iterator, iterable, children) do
    %{type: :loop, iterator: iterator, iterable: iterable, children: children}
  end

  def fragment(children), do: %{type: :fragment, children: children}

  def filter(name, args \\ []), do: %{name: name, args: args}

  def test_path(path), do: %{path: path, op: nil, value: nil}
  def test_compare(path, op, value), do: %{path: path, op: op, value: value}
  def test_logical(left, op, right), do: %{left: left, op: op, right: right}

  # Serialization

  def to_json(nodes) when is_list(nodes), do: Jason.encode!(nodes)
  def to_json(node) when is_map(node), do: Jason.encode!(node)

  def from_json(json) when is_binary(json), do: Jason.decode!(json)
end
