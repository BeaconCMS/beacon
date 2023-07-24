defmodule Beacon.BlueprintConverter do
  require Floki

  def parse_html(html_string) do
    case Floki.parse_document(html_string) do
      { :ok, data } ->
        reshape(data)
      { _, _error} ->
        raise("Error parsing blueprint")
    end
  end

  defp convert_attr({"class", value}) do
    { "class", String.split(value, " ") }
  end
  defp convert_attr({key, value}), do: {key, value}
  defp convert_attrs(attrs) do
      attrs
        |> Enum.map(&convert_attr(&1))
        |> Enum.filter(& !is_nil(&1))
        |> Map.new()
  end
  defp convert_node({"svg", attrs, content}) do
      new_attrs = convert_attrs(attrs)
      %{ "tag" => "svg", "attributes" => new_attrs, "content" => [Floki.raw_html(content)] }
  end
  defp convert_node({tag, attrs, content}) do
      new_attrs = convert_attrs(attrs)
      %{ "tag" => tag, "attributes" => new_attrs, "content" => reshape(content) }
  end

  defp reshape([data]) when is_binary(data), do: [data]
  defp reshape(data) do
    data
    |> Enum.map(&convert_node(&1))
  end
end
