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

  defp transform_node(%{"tag" => "eex", "attrs" => _attrs, "content" => content}) do
    ["<%=", content, "%>"]
  end

  defp transform_node(%{"tag" => "eex_comment", "content" => content}) do
    ["<%!--", content, "--%>"]
  end

  defp transform_node(%{"tag" => "eex_block", "blocks" => blocks, "arg" => arg}) do
    ["<%=", arg, " %>", Enum.map(blocks, &transform_block/1)]
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

  defp transform_block(%{"content" => content, "key" => key}) do
    [decode_nodes(content), "<%", key, "%>"]
  end

  defp transform_attrs(attrs) do
    Enum.map_join(attrs, " ", &transform_attr/1)
  end

  defp transform_attr({key, true}) do
    key
  end

  # Matches attributes whose values are wrapped in `{` and `}` (eex expressions)
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
end
