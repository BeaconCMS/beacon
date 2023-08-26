defmodule Beacon.Template.HEEx.HEExDecoder do
  @moduledoc false

  @doc """
  Decodes a nested list of tokens into a formatted HEEx template binary.
  """
  @spec decode(list()) :: String.t()
  def decode(ast) do
    ast
    |> transform()
    |> :erlang.iolist_to_binary()
    |> Phoenix.LiveView.HTMLFormatter.format(heex_line_length: 100)
    |> String.trim()
  end

  defp transform([str]) when is_binary(str), do: str

  defp transform(ast) do
    Enum.map(ast, &transform_node/1)
  end

  defp transform_node(%{"tag" => "eex", "attrs" => _attrs, "content" => content}) do
    ["<%=", content, "%>"]
  end

  defp transform_node(%{"tag" => tag, "attrs" => %{"self_close" => true} = attrs, "content" => []}) do
    ["<", tag, " ", transform_attrs(Map.delete(attrs, "self_close")), "/>"]
  end

  defp transform_node(%{"tag" => tag, "attrs" => attrs, "content" => content}) when map_size(attrs) == 0 do
    ["<", tag, ">", transform(content), "</", tag, ">"]
  end

  defp transform_node(%{"tag" => tag, "attrs" => attrs, "content" => content}) do
    ["<", tag, " ", transform_attrs(attrs), ">", transform(content), "</", tag, ">"]
  end

  defp transform_node(str) when is_binary(str), do: str

  defp transform_attrs(attrs) do
    Enum.map_join(attrs, " ", &transform_attr/1)
  end

  defp transform_attr({key, true}) do
    [key]
  end

  # Matches attributes whose values are wrapped in `{` and `}` (eex expressions)
  defp transform_attr({key, s}) when binary_part(s, 0, 1) == "{" and binary_part(s, byte_size(s) - 1, 1) == "}" do
    [key, "=", s]
  end

  defp transform_attr({key, value}) do
    [key, "=\"", value, "\""]
  end
end
