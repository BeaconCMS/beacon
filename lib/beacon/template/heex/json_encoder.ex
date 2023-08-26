defmodule Beacon.Template.HEEx.JSONEncoder do
  @moduledoc false

  @doc """
  Encodes a HEEx `template` into a format that can be encoded into JSON.

  The returned data structure can be serialized and sent over the wire to any client that uses a JSON API,
  and it aims to retain all the information we need to reconstruct back the original template from it.

  ## Example

      iex> encode(~S|
      <header>
        <.link patch="/">
          <h1 class="bg-red">My Site</h1>
        </.link>
      </header>
      |, :my_site)
      [
        %{
          "attrs" => %{},
          "content" => [
            %{
              "attrs" => %{"patch" => "/"},
              "content" => [
                %{
                  "attrs" => %{"class" => "bg-red"},
                  "content" => ["My Site"],
                  "tag" => "h1"
                }
              ],
              "rendered_html" => "<a href=\"/\" data-phx-link=\"patch\" data-phx-link-state=\"push\">\n    <h1 class=\"bg-red\">My Site</h1>\n  </a>",
              "tag" => ".link"
            }
          ],
          "tag" => "header"
        }
      ]

  """
  @spec encode(String.t(), Beacon.Types.Site.t()) :: {:ok, list()} | {:error, String.t()}
  def encode(template, site) when is_binary(template) and is_atom(site) do
    case Beacon.Template.HEEx.Tokenizer.tokenize(template) do
      {:ok, tokens} -> {:ok, encode_tokens(tokens, site)}
      error -> error
    end
  rescue
    exception ->
      message = """
      failed to encode the HEEx template

      Got:

        #{Exception.message(exception)}

      """

      reraise Beacon.ParserError, [message: message], __STACKTRACE__
  end

  defp encode_tokens(ast, site) when is_list(ast) and is_atom(site) do
    transform(ast, [], site)
  end

  defp transform([head], acc, site) do
    case transform_entry(head, site) do
      nil ->
        acc

      entry ->
        [entry | acc]
    end
  end

  defp transform([head | tail], acc, site) do
    case transform_entry(head, site) do
      nil ->
        transform(tail, acc, site)

      entry ->
        [entry | transform(tail, acc, site)]
    end
  end

  defp transform([], acc, _), do: acc

  # Strips blank text nodes and insignificant whitespace before or after text.
  defp transform_entry({:text, text, _}, _site) do
    cond do
      :binary.first(text) in ~c"\n" or :binary.last(text) in ~c"\n" ->
        text = String.trim(text)
        if text != "", do: text

      :default ->
        text
    end
  end

  defp transform_entry({:eex, str, _} = ast_node, site) do
    # FIXME: assigns
    html =
      Beacon.Template.HEEx.render_component(site, reconstruct_template(ast_node), %{
        beacon_path_params: %{},
        beacon_live_data: %{year: "2023", month: "August"}
      })

    %{
      "tag" => "eex",
      "attrs" => %{},
      "content" => [str],
      "rendered_html" => html
    }
  end

  defp transform_entry({:eex_block, arg, content_ast}, site) do
    %{
      "tag" => "eex_block",
      "arg" => arg,
      "blocks" => Enum.map(content_ast, fn block -> transform_block(block, site) end)
    }
  end

  defp transform_entry({:eex_comment, comment}, _site) do
    %{
      "tag" => "eex_comment",
      "attrs" => %{},
      "content" => List.wrap(comment)
    }
  end

  defp transform_entry({:html_comment, [{:text, comment, _}]}, _site) do
    %{
      "tag" => "html_comment",
      "attrs" => %{},
      "content" => comment
    }
  end

  defp transform_entry({:tag_block, tag, attrs, content_ast, _} = ast_node, site) do
    entry = %{
      "tag" => tag,
      "attrs" => transform_attrs(attrs),
      "content" => encode_tokens(content_ast, site)
    }

    case tag do
      "." <> _rest ->
        rendered_html = Beacon.Template.HEEx.render_component(site, reconstruct_template(ast_node), %{text: "Sample text"})
        Map.put(entry, "rendered_html", rendered_html)

      _ ->
        entry
    end
  end

  defp transform_entry({:tag_self_close, tag, attrs}, _site) do
    %{
      "tag" => tag,
      "attrs" => transform_attrs(attrs, true),
      "content" => []
    }
  end

  defp reconstruct_template({:tag_block, tag, attrs, content_ast, _}) do
    "<" <> tag <> reconstruct_attrs(attrs) <> ">" <> Enum.map_join(content_ast, &reconstruct_template/1) <> "</" <> tag <> ">"
  end

  defp reconstruct_template({:eex, expr, _}) do
    "<%=" <> expr <> "%>"
  end

  defp reconstruct_template({:text, text, _}), do: text

  defp reconstruct_attrs([]), do: ""

  defp reconstruct_attrs(attrs) do
    " " <> Enum.map_join(attrs, &reconstruct_attr/1)
  end

  defp reconstruct_attr({name, {:string, content, _}, _}) do
    ~s|#{name}="#{content}"|
  end

  defp reconstruct_attr({name, {:expr, content, _}, _}) do
    "#{name}={#{content}}"
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

  defp transform_block({content_ast, key}, site) do
    %{
      "key" => key,
      "content" => encode_tokens(content_ast, site)
    }
  end
end
