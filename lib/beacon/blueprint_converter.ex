defmodule Beacon.BlueprintConverter do
  require Floki

  def parse_html(html_string) do
    case Floki.parse_document(html_string) do
      {:ok, data} ->
        reshape(data)

      {_, _error} ->
        raise("Error parsing blueprint")
    end
  end

  def generate_html(id, json_ast) do
    %{"tag" => tag, "content" => content, "attributes" => attributes} = json_ast

    attributes =
      attributes
      |> Map.put("id", id)
      |> Map.put("root", true)

    render_node(%{"tag" => tag, "content" => content, "attributes" => attributes})
  end

  defp convert_attr({"class", value}) do
    {"class", String.split(value, " ")}
  end

  defp convert_attr({key, value}), do: {key, value}

  defp convert_attrs(attrs) do
    attrs
    |> Enum.map(&convert_attr(&1))
    |> Enum.filter(&(!is_nil(&1)))
    |> Map.new()
  end

  defp convert_node({"svg", attrs, content}) do
    new_attrs = convert_attrs(attrs)
    %{"tag" => "svg", "attributes" => new_attrs, "content" => [Floki.raw_html(content)]}
  end

  defp convert_node({tag, attrs, content}) do
    new_attrs = convert_attrs(attrs)
    %{"tag" => tag, "attributes" => new_attrs, "content" => reshape(content)}
  end

  defp reshape([data]) when is_binary(data), do: [data]

  defp reshape(data) do
    data
    |> Enum.map(&convert_node(&1))
  end

  defp render_node(node) when is_binary(node), do: node
  # Special case to just output content as HTML
  defp render_node(%{"tag" => "raw", "content" => content}), do: content
  defp render_node(%{"tag" => "img", "attributes" => attributes}) do
    "<img#{render_attrs(attributes)}/>"
  end

  defp render_node(%{"tag" => tag, "attributes" => attributes, "content" => content}) do
    """
    <#{tag}#{render_attrs(attributes)}>
      #{content |> Enum.map_join(&render_node(&1))}
    </#{tag}>
    """
  end

  defp render_attrs(attributes) when attributes == %{}, do: ""

  defp render_attrs(attributes) do
    str = Enum.map_join(attributes, " ", fn {key, val} -> render_attr(key, val) end)
    " " <> str
  end

  defp render_attr(key, val) when is_list(val), do: "#{key}=\"#{Enum.join(val, " ")}\""
  defp render_attr("id", val), do: "data-id=\"#{val}\""
  defp render_attr("slot", false), do: ""
  defp render_attr("slot", _), do: "data-slot"
  defp render_attr("root", _), do: "data-root"
  defp render_attr(key, val), do: "#{key}=\"#{val}\""
end
