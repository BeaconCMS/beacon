defmodule Beacon.Template.HEEx.HeexTransformer do
  def transform(ast) do
    :erlang.iolist_to_binary(_transform(ast))
  end

  defp _transform([str]) when is_binary(str), do: str

  defp _transform(ast) do
    ast
    |> Enum.map(&transform_node/1)
  end

  defp transform_node(%{"tag" => "eex", "attrs" => _attrs, "content" => content}) do
    ["<%=", content, "%>"]
  end

  defp transform_node(%{"tag" => tag, "attrs" => %{"self_close" => true} = attrs, "content" => []}) do
    ["<", tag, " ", transform_attrs(Map.delete(attrs, "self_close")), "/>"]
  end

  defp transform_node(%{"tag" => tag, "attrs" => attrs, "content" => content}) when map_size(attrs) == 0 do
    ["<", tag, ">", _transform(content), "</", tag, ">"]
  end

  defp transform_node(%{"tag" => tag, "attrs" => attrs, "content" => content}) do
    ["<", tag, " ", transform_attrs(attrs), ">", _transform(content), "</", tag, ">"]
  end

  defp transform_node(str) when is_binary(str), do: str

  defp transform_attrs(attrs) do
    Enum.map_join(attrs, " ", &transform_attr/1)
  end

  defp transform_attr({key, true}) do
    [key]
  end

  # Matches attributes which values is wrapped in {} (expressions)
  defp transform_attr({key, s}) when binary_part(s, 0, 1) == "{" and binary_part(s, byte_size(s) - 1, 1) == "}" do
    [key, "=", s]
  end

  defp transform_attr({key, value}) do
    [key, "=\"", value, "\""]
  end
end
