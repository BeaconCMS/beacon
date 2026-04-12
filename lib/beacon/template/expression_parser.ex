defmodule Beacon.Template.ExpressionParser do
  @moduledoc """
  Parses expressions inside `{{ }}` interpolations and `:if`/`:for` directive values.

  Handles:
  - Dot-notation paths: `post.title`, `blog_listing.past_posts`
  - Filters with pipe syntax: `post.title | truncate: 200`
  - Comparison operators: `post.status == "published"`
  - Boolean operators: `post.featured and post.published`
  - For-loop syntax: `post in blog_listing.past_posts`
  - String literals: `"published"`, `'draft'`
  - Number literals: `42`, `3.14`
  - Boolean literals: `true`, `false`
  """

  @comparison_ops ~w(== != > < >= <=)

  @doc """
  Parse an interpolation expression (inside `{{ }}`).
  Returns `%{path: ..., filters: [...]}`.
  """
  def parse_interpolation(expr) when is_binary(expr) do
    expr = String.trim(expr)

    case String.split(expr, "|", parts: 2) do
      [path_str] ->
        %{type: :expression, path: String.trim(path_str), filters: []}

      [path_str, filter_str] ->
        path = String.trim(path_str)
        filters = parse_filters(filter_str)
        %{type: :expression, path: path, filters: filters}
    end
  end

  @doc """
  Parse a conditional expression (inside `:if` or `:else-if`).
  Returns a test expression map.
  """
  def parse_condition(expr) when is_binary(expr) do
    expr = String.trim(expr)
    parse_logical(expr)
  end

  @doc """
  Parse a for-loop expression (inside `:for`).
  Returns `{iterator, iterable}`.
  """
  def parse_for(expr) when is_binary(expr) do
    expr = String.trim(expr)

    case String.split(expr, " in ", parts: 2) do
      [iterator, iterable] ->
        {String.trim(iterator), String.trim(iterable)}

      _ ->
        raise Beacon.Template.ParseError, "invalid :for expression: #{inspect(expr)}, expected 'item in collection'"
    end
  end

  @doc """
  Parse a filter chain string like `truncate: 200 | upcase`.
  Returns a list of `%{name: ..., args: [...]}`.
  """
  def parse_filters(filter_str) do
    filter_str
    |> String.split("|")
    |> Enum.map(&parse_single_filter/1)
  end

  defp parse_single_filter(filter_str) do
    filter_str = String.trim(filter_str)

    case String.split(filter_str, ":", parts: 2) do
      [name] ->
        %{name: String.trim(name), args: []}

      [name, args_str] ->
        args = parse_filter_args(String.trim(args_str))
        %{name: String.trim(name), args: args}
    end
  end

  defp parse_filter_args(args_str) do
    args_str
    |> split_respecting_quotes(",")
    |> Enum.map(fn arg ->
      arg = String.trim(arg)
      parse_literal(arg)
    end)
  end

  # Split a string on a delimiter, but don't split inside quoted strings
  defp split_respecting_quotes(str, delimiter) do
    {parts, current, _in_quote} =
      str
      |> String.graphemes()
      |> Enum.reduce({[], "", nil}, fn
        "\"", {parts, current, nil} -> {parts, current <> "\"", "\""}
        "\"", {parts, current, "\""} -> {parts, current <> "\"", nil}
        "'", {parts, current, nil} -> {parts, current <> "'", "'"}
        "'", {parts, current, "'"} -> {parts, current <> "'", nil}
        char, {parts, current, nil} ->
          if char == delimiter do
            {[current | parts], "", nil}
          else
            {parts, current <> char, nil}
          end
        char, {parts, current, quote_char} ->
          {parts, current <> char, quote_char}
      end)

    Enum.reverse([current | parts])
  end

  defp parse_logical(expr) do
    # Try splitting on " and " or " or " (lowest precedence)
    cond do
      parts = split_logical(expr, " or ") ->
        {left, right} = parts
        %{left: parse_logical(left), op: "or", right: parse_logical(right)}

      parts = split_logical(expr, " and ") ->
        {left, right} = parts
        %{left: parse_logical(left), op: "and", right: parse_logical(right)}

      true ->
        parse_comparison(expr)
    end
  end

  defp split_logical(expr, op) do
    case String.split(expr, op, parts: 2) do
      [left, right] when left != "" and right != "" ->
        {String.trim(left), String.trim(right)}

      _ ->
        nil
    end
  end

  defp parse_comparison(expr) do
    Enum.find_value(@comparison_ops, fn op ->
      case String.split(expr, " #{op} ", parts: 2) do
        [left, right] when left != "" and right != "" ->
          %{path: String.trim(left), op: op, value: parse_literal(String.trim(right))}

        _ ->
          nil
      end
    end) || %{path: expr, op: nil, value: nil}
  end

  @doc """
  Parse a literal value from a string.
  """
  def parse_literal(str) do
    str = String.trim(str)

    cond do
      str == "true" -> true
      str == "false" -> false
      str == "nil" or str == "null" -> nil
      String.starts_with?(str, "\"") and String.ends_with?(str, "\"") ->
        String.slice(str, 1..-2//1)
      String.starts_with?(str, "'") and String.ends_with?(str, "'") ->
        String.slice(str, 1..-2//1)
      match?({_, ""}, Integer.parse(str)) ->
        String.to_integer(str)
      match?({_, ""}, Float.parse(str)) ->
        String.to_float(str)
      true ->
        str
    end
  end
end
