defmodule Beacon.Template.HEEx.HEExDecoder do
  @moduledoc false

  alias Beacon.Template.HEEx.JSONEncoder

  @type eex_node :: tuple()

  @doc """
  Decodes a nested list of tokens or a EEx node into a formatted HEEx template binary.

  A nested list of tokens must be generated with `Beacon.Template.HEEx.JSONEncoder.encode/3`.

  ## Examples

      iex> decode({:eex, "@project.name", %{line: 1, opt: ~c"=", column: 1}})
      "<%= @project.name %>"

  """
  @spec decode([JSONEncoder.token()] | eex_node()) :: String.t()
  def decode(tokens_eex_node)

  def decode(tokens_eex_node) when is_list(tokens_eex_node) do
    tokens_eex_node
    |> decode_nodes()
    |> IO.iodata_to_binary()
    |> Phoenix.LiveView.HTMLFormatter.format(heex_line_length: 100)
  end

  def decode(tokens_eex_node) when is_tuple(tokens_eex_node) do
    tokens_eex_node
    |> decode_node()
    |> IO.iodata_to_binary()
    |> Phoenix.LiveView.HTMLFormatter.format(heex_line_length: 100)
  end

  defp decode_nodes([str]) when is_binary(str), do: str

  defp decode_nodes(ast) when is_list(ast) do
    Enum.map(ast, &transform_node/1)
  end

  defp transform_node(%{"tag" => "eex", "attrs" => _attrs, "content" => content, "metadata" => %{"opt" => []}}) do
    ["<%", content, "%>"]
  end

  defp transform_node(%{"tag" => "eex", "attrs" => _attrs, "content" => content}) do
    ["<%=", content, "%>"]
  end

  defp transform_node(%{"tag" => "html_comment", "content" => content}) do
    ["<!--", content, "-->"]
  end

  defp transform_node(%{"tag" => "eex_comment", "content" => content}) do
    ["<%!--", content, "--%>"]
  end

  defp transform_node(%{"tag" => "eex_block", "ast" => ast}) do
    [decode_eex_block(ast)]
  end

  defp transform_node(%{"tag" => tag, "attrs" => %{"self_close" => true} = attrs, "content" => []}) do
    attrs = Map.delete(attrs, "self_close")
    ["<", tag, " ", transform_attrs(attrs), "/>"]
  end

  defp transform_node(%{"tag" => tag, "attrs" => attrs, "content" => content}) when map_size(attrs) == 0 do
    ["<", tag, ">", decode_nodes(content), "</", tag, ">"]
  end

  defp transform_node(%{"tag" => tag, "attrs" => attrs, "content" => content}) do
    ["<", tag, " ", transform_attrs(attrs), ">", decode_nodes(content), "</", tag, ">"]
  end

  defp transform_node(str) when is_binary(str) do
    str
  end

  defp transform_attrs(attrs) do
    Enum.map_join(attrs, " ", &transform_attr/1)
  end

  defp transform_attr({key, true}) do
    key
  end

  # matches attributes whose values are wrapped in `{` and `}` (eex expressions)
  defp transform_attr({key, value})
       when binary_part(value, 0, 1) == "{" and binary_part(value, byte_size(value) - 1, 1) == "}" do
    [key, "=", value]
  end

  defp transform_attr({key, value}) do
    [key, "=", ?", value, ?"]
  end

  defp decode_node({:tag_block, tag, attrs, content_ast, _}) do
    ["<", tag, reconstruct_attrs(attrs), ">", Enum.map_join(content_ast, &decode_node/1), "</", tag, ">"]
  end

  defp decode_node({:tag_self_close, tag, attrs}) do
    ["<", tag, reconstruct_attrs(attrs), "/>"]
  end

  defp decode_node({:eex, expr, %{opt: []}}) do
    ["<%", expr, "%>"]
  end

  defp decode_node({:eex, expr, _}) do
    ["<%=", expr, "%>"]
  end

  defp decode_node({:text, text, _}), do: text

  defp reconstruct_attrs([]), do: ""

  defp reconstruct_attrs(attrs) do
    [" ", Enum.map_join(attrs, &reconstruct_attr/1)]
  end

  defp reconstruct_attr({name, {:string, content, _}, _}) do
    [name, "=", ?", content, ?"]
  end

  defp reconstruct_attr({name, {:expr, content, _}, _}) do
    [name, "=", ?{, content, ?}]
  end

  defp decode_eex_block(ast) do
    %{"type" => "eex_block", "content" => content, "children" => children} = Jason.decode!(ast)

    children =
      children
      |> Enum.reduce([], fn node, acc -> decode_eex_block_node(node, acc) end)
      |> Enum.reverse()

    ["<%= ", content, " %>", children]
  end

  defp decode_eex_block_node(%{"type" => "eex_block_clause", "content" => clause, "children" => children}, acc) do
    children = decode_eex_block_node(children, [])
    [[children, "<% ", clause, " %>"] | acc]
  end

  defp decode_eex_block_node([head | tail], acc) do
    head = decode_eex_block_node(head)
    decode_eex_block_node(tail, acc ++ [head])
  end

  defp decode_eex_block_node([], acc), do: acc

  defp decode_eex_block_node(%{"type" => "text", "content" => content}) do
    [content]
  end

  defp decode_eex_block_node(%{"type" => "tag_block", "tag" => tag, "attrs" => attrs, "metadata" => _metadata, "children" => children}) do
    attrs = transform_attrs(attrs)
    children = decode_eex_block_node(children, [])
    ["<", tag, " ", attrs, ">", children, "</", tag, ">"]
  end

  defp decode_eex_block_node(%{"type" => "tag_self_close", "tag" => tag, "attrs" => attrs}) do
    attrs = transform_attrs(attrs)
    ["<", tag, " ", attrs, "/>"]
  end

  defp decode_eex_block_node(%{"type" => "eex", "content" => expr, "metadata" => %{"opt" => ~c"="}}) do
    ["<%= ", expr, " %>"]
  end
end
