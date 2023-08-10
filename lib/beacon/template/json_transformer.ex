defmodule Beacon.Template.HEEx.JsonTransformer do
  @moduledoc """
  Transforms the AST returned by Beacon.Template.HEEx.Tokenizer.parse into a
  more json-friendly array of maps, one that can be serialized and sent over the wire
  to any client that uses a JSON api.
  It aims to retain all the information we need to reconstruct back the original
  template from it.

  From an AST like:
  ```elixir
  [
    {:tag_block, "section", [],
     [
       {:text, "\n  ", %{newlines: 1}},
       {:tag_block, "p", [], [{:eex, "user.name", %{column: 6, line: 2, opt: '='}}], %{mode: :block}},
       {:text, "\n  ", %{newlines: 1}},
       {:eex_block, "if true do",
        [
          {[{:text, " ", %{newlines: 0}}, {:tag_block, "p", [], [{:text, "this", %{newlines: 0}}], %{mode: :block}}], "else"},
          {[{:tag_block, "p", [], [{:text, "that", %{newlines: 0}}], %{mode: :block}}], "end"}
        ]},
       {:text, "\n", %{newlines: 1}}
     ], %{mode: :block}}
  ]
  ```
  it will generate a result like this:
  [
    %{
      "tag" => "section",
      "content" => [
        "\n  ",
        %{"tag" => "p", "content" => [%{tag: :eex, "content" => "user.name", "attrs" => %{}}], "attrs" => %{}},
        "\n  ",
        %{
          "tag" => "eex_block",
          "arg" => "if true do",
          "blocks" => [
            %{"key" => "else", "content" => [" ", %{"tag" => "p", "content" => ["this"], "attrs" => %{}}]},
            %{"key" => "end", "content" => [%{"tag" => "p", "content" => ["that"], "attrs" => %{}}]}
          ]
        },
        "\n"
      ],
      "attrs" => %{}
    }
  ]
  """
  def transform(ast) do
    _transform(ast, [])
  end

  defp _transform([head], acc) do
    case transform_entry(head) do
      nil ->
        acc

      entry ->
        [entry | acc]
    end
  end

  defp _transform([head | tail], acc) do
    case transform_entry(head) do
      nil ->
        _transform(tail, acc)

      entry ->
        [entry | _transform(tail, acc)]
    end
  end

  defp _transform([], acc), do: acc

  # Strips blank text nodes and insignificant whitespace before or after text.
  defp transform_entry({:text, str, _}) do
    str = String.trim(str)
    if str != "", do: str
  end

  defp transform_entry({:eex, str, _}) do
    %{
      "tag" => "eex",
      "attrs" => %{},
      "content" => str
    }
  end

  defp transform_entry({:eex_block, arg, content_ast}) do
    %{
      "tag" => "eex_block",
      "arg" => arg,
      "blocks" => Enum.map(content_ast, &transform_block/1)
    }
  end

  defp transform_entry({:tag_block, tag, attrs, content_ast, _}) do
    %{
      "tag" => tag,
      "attrs" => transform_attrs(attrs),
      "content" => transform(content_ast)
    }
  end

  defp transform_entry({:tag_self_close, tag, attrs}) do
    %{
      "tag" => tag,
      "attrs" => transform_attrs(attrs, true),
      "content" => []
    }
  end

  defp transform_attrs([]), do: %{}

  defp transform_attrs(attrs) do
    attrs
    |> Enum.map(&transform_attr/1)
    |> Enum.reduce(%{}, fn {attr_name, value}, acc ->
      Map.put(acc, attr_name, value)
    end)
  end

  defp transform_attrs(attrs, true) do
    transform_attrs(attrs)
    |> Map.put("self_close", true)
  end

  defp transform_attr({attr_name, {:string, value, _}, _}) do
    {attr_name, value}
  end

  defp transform_attr({attr_name, {:expr, value, _}, _}) do
    {attr_name, "{" <> value <> "}"}
  end

  defp transform_attr({attr_name, nil, _}) do
    {attr_name, true}
  end

  defp transform_block({content_ast, key}) do
    %{
      "key" => key,
      "content" => transform(content_ast)
    }
  end
end
