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
       "blocks" => [%{"key" => String.t(), "content" => content()}]
      }

      content = [heex_node() | eex_node() | eex_block_node() | String.t()]

  Note that:

    * `rendered_html` key is optional
    * Comprehensions are not supported

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
      message = """
      failed to encode the HEEx template

      Got:

        #{Exception.message(exception)}

      """

      reraise Beacon.ParserError, [message: message], __STACKTRACE__
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

  # Strips blank text nodes and insignificant whitespace before or after text.
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

  defp transform_entry({:eex_block, arg, content}, site, assigns) do
    %{
      "tag" => "eex_block",
      "arg" => arg,
      "blocks" => Enum.map(content, fn block -> transform_block(block, site, assigns) end)
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

    case tag do
      "." <> _rest ->
        rendered_html = Beacon.Template.HEEx.render(site, HEExDecoder.decode(node), assigns)
        Map.put(entry, "rendered_html", rendered_html)

      _ ->
        entry
    end
  end

  defp transform_entry({:tag_self_close, tag, attrs}, _site, _assigns) do
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

  defp transform_block({content, key}, site, assigns) do
    %{
      "key" => key,
      "content" => encode_tokens(content, site, assigns)
    }
  end
end
