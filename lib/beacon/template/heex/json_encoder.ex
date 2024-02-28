defmodule Beacon.Template.HEEx.JSONEncoder do
  @moduledoc false

  alias Beacon.Template.HEEx.HEExDecoder

  @type token :: map()

  @doc """
  Encodes a HEEx `template` into a format that can be encoded into JSON.

  The returned data structure can be serialized and sent over the wire to any client that uses a JSON API,
  and it aims to retain all the information we need to reconstruct back the original template from it.

  ## Data Structure

  The encoded data structured emitted at the end is a list of tokens composed of either a `heex_node` or a `eex_node`,
  as specified below:

      tokens = [heex_node() | eex_node() | eex_block_node()]

      heex_node = %{
        "tag" => String.t(),
        "attrs" => %{String.t() => String.t()},
        "content" => content(),
        "rendered_html" => String.t()
      }

      eex_node = %{
        "tag" => "eex",
        "metadata" => %{opt: list()},
        "attrs" => %{String.t() => String.t()},
        "content" => content(),
        "rendered_html" => String.t(),
      }

      eex_block_node = %{
        "tag" => "eex_block",
        "arg" => String.t(),
        "ast" => [eex_node()]
      }

      content = [heex_node() | eex_node() | eex_block_node() | String.t()]

  Note that:

    * `rendered_html` key is optional

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
  @spec encode(Beacon.Types.Site.t(), String.t(), map()) :: {:ok, [token()]} | {:error, String.t()}
  def encode(site, template, assigns \\ %{})

  def encode(site, nil = _template, assigns) when is_atom(site) and is_map(assigns) do
    encode(site, "", assigns)
  end

  def encode(site, template, assigns) when is_atom(site) and is_binary(template) and is_map(assigns) do
    case Beacon.Template.HEEx.Tokenizer.tokenize(template) do
      {:ok, tokens} -> {:ok, encode_tokens(tokens, site, assigns)}
      error -> error
    end
  rescue
    exception ->
      {:error, Exception.message(exception)}
  end

  defp encode_tokens(ast, site, assigns) do
    transform(ast, [], site, assigns)
  end

  defp transform([head], acc, site, assigns) do
    case transform_entry(head, site, assigns) do
      nil ->
        acc

      entry ->
        [entry | acc]
    end
  end

  defp transform([head | tail], acc, site, assigns) do
    case transform_entry(head, site, assigns) do
      nil ->
        transform(tail, acc, site, assigns)

      entry ->
        [entry | transform(tail, acc, site, assigns)]
    end
  end

  defp transform([], acc, _site, _assigns), do: acc

  # strips out blank text nodes and insignificant whitespace before or after text.
  defp transform_entry({:text, text, _}, _site, _assigns) do
    cond do
      :binary.first(text) in ~c"\n" or :binary.last(text) in ~c"\n" ->
        text = String.trim(text)
        if text != "", do: text

      :default ->
        text
    end
  end

  defp transform_entry({:eex, expr, %{opt: opt}} = node, site, assigns) do
    html = Beacon.Template.HEEx.render(site, HEExDecoder.decode(node), assigns)

    %{
      "tag" => "eex",
      "metadata" => %{"opt" => opt},
      "attrs" => %{},
      "content" => [expr],
      "rendered_html" => html
    }
  end

  defp transform_entry({:eex_block, arg, _content} = entry, site, assigns) do
    arg = String.trim(arg)

    %{
      "tag" => "eex_block",
      "arg" => arg,
      "rendered_html" => render_eex_block(site, assigns, entry),
      "ast" => entry |> encode_eex_block() |> Jason.encode!()
    }
  end

  defp transform_entry({:eex_comment, text}, _site, _assigns) do
    %{
      "tag" => "eex_comment",
      "attrs" => %{},
      "content" => List.wrap(text)
    }
  end

  defp transform_entry({:html_comment, [{:text, text, _}]}, _site, _assigns) do
    text =
      text
      |> String.replace("<!--", "")
      |> String.replace("-->", "")

    %{
      "tag" => "html_comment",
      "attrs" => %{},
      "content" => List.wrap(text)
    }
  end

  defp transform_entry({:tag_block, tag, attrs, content, _} = node, site, assigns) do
    entry = %{
      "tag" => tag,
      "attrs" => transform_attrs(attrs),
      "content" => encode_tokens(content, site, assigns)
    }

    maybe_add_rendered_html(site, assigns, node, entry)
  end

  defp transform_entry({:tag_self_close, tag, attrs} = node, site, assigns) do
    entry = %{
      "tag" => tag,
      "attrs" => transform_attrs(attrs, true),
      "content" => []
    }

    maybe_add_rendered_html(site, assigns, node, entry)
  end

  defp maybe_add_rendered_html(site, assigns, node, entry) do
    tag = elem(node, 1)
    attrs = elem(node, 2)

    add_rendered_html = fn ->
      rendered_html = Beacon.Template.HEEx.render(site, HEExDecoder.decode(node), assigns)
      Map.put(entry, "rendered_html", rendered_html)
    end

    has_eex_in_attrs? =
      Enum.reduce_while(attrs, false, fn
        {_, {:expr, _, _}, _}, _acc -> {:halt, true}
        _attr, _acc -> {:cont, false}
      end)

    cond do
      # start with '.' or a capital letter
      String.match?(tag, ~r/^[A-Z]|\./) -> add_rendered_html.()
      has_eex_in_attrs? -> add_rendered_html.()
      :else -> entry
    end
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
    attrs
    |> transform_attrs()
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

  defp render_eex_block(site, assigns, {:eex_block, arg, nodes}) do
    arg = ["<%= ", arg, " %>", "\n"]

    template =
      Enum.reduce(nodes, [arg], fn node, acc ->
        [[extract_node_text(node), " \n "] | acc]
      end)
      |> Enum.reverse()
      |> List.to_string()

    Beacon.Template.HEEx.render(site, template, assigns)
  end

  defp extract_node_text({nodes, text} = value) when is_list(nodes) and is_binary(text) do
    value
    |> Tuple.to_list()
    |> Enum.reduce([], fn node, acc -> [extract_node_text(node) | acc] end)
    |> Enum.reverse()
  end

  defp extract_node_text(value) when is_list(value) do
    value
    |> Enum.reduce([], fn node, acc -> [extract_node_text(node) | acc] end)
    |> Enum.reverse()
  end

  # TODO: augment tokenizer to mark these nodes as elixir expressions (eex block clauses) currently it's marked as text
  defp extract_node_text(value) when is_binary(value) do
    cond do
      value in ["else", "end"] -> ["<% ", value, " %>"]
      # ends with ' ->'
      String.match?(value, ~r/.* ->$/) -> ["<% ", value, " %>"]
      :default -> value
    end
  end

  defp extract_node_text({:text, text, _}), do: text

  defp extract_node_text({:html_comment, children}), do: [extract_node_text(children), "\n"]

  # TODO: eex comments are stripped out of rendered html by the heex engine
  defp extract_node_text({:eex_comment, _content}), do: []

  defp extract_node_text({:eex, expr, %{opt: ~c"="}}), do: ["<%= ", expr, " %>"]

  defp extract_node_text({:eex, expr, _}), do: ["<% ", expr, " %>"]

  defp extract_node_text({:eex_block, expr, children}), do: ["<%= ", expr, " %>", extract_node_text(children)]

  defp extract_node_text({:tag_self_close, tag, attrs}) do
    attrs =
      Enum.reduce(attrs, [], fn attr, acc ->
        [extract_node_attr(attr) | acc]
      end)

    [?<, tag, " ", attrs, "/>"]
  end

  defp extract_node_text({:tag_block, tag, _, children, _}) do
    [?<, tag, ?>, extract_node_text(children), "</", tag, ">"]
  end

  defp extract_node_attr({attr, {:string, text, _}, _}), do: [attr, ?=, ?", text, ?", " "]
  defp extract_node_attr({attr, {:expr, expr, _}, _}), do: [attr, ?=, ?{, expr, ?}, " "]

  def encode_eex_block({:eex_block, arg, children}) do
    children = encode_eex_block_node(children, [])
    %{type: :eex_block, content: arg, children: children}
  end

  def encode_eex_block_node([head | tail], acc) do
    head = encode_eex_block_node(head)
    encode_eex_block_node(tail, acc ++ [head])
  end

  def encode_eex_block_node([], acc), do: acc

  def encode_eex_block_node({type, children}) when type in [:html_comment] do
    children = encode_eex_block_node(children, [])
    %{type: type, children: children}
  end

  def encode_eex_block_node({type, content}) when type in [:eex_comment] and is_binary(content) do
    %{type: type, content: content}
  end

  def encode_eex_block_node({children, clause}) do
    children = encode_eex_block_node(children, [])
    %{type: :eex_block_clause, content: clause, children: children}
  end

  def encode_eex_block_node({:eex_block, content, children}) do
    children = encode_eex_block_node(children, [])
    %{type: :eex_block, content: content, children: children}
  end

  def encode_eex_block_node({type, content, metadata}) when is_binary(content) and is_map(metadata) do
    %{type: type, content: content, metadata: metadata}
  end

  def encode_eex_block_node({type, tag, attrs}) when is_list(attrs) do
    attrs = transform_attrs(attrs)
    %{type: type, tag: tag, attrs: attrs}
  end

  def encode_eex_block_node({type, tag, attrs, children, metadata}) do
    children = encode_eex_block_node(children, [])
    attrs = transform_attrs(attrs)
    %{type: type, tag: tag, attrs: attrs, metadata: metadata, children: children}
  end
end
