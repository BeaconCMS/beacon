defmodule Beacon.Content.Snippets.TagHelper do
  @moduledoc false

  @behaviour Solid.Tag

  import NimbleParsec
  alias Solid.Parser.Argument
  alias Solid.Parser.BaseTag
  alias Solid.Parser.Literal

  @impl true
  def spec(_parser) do
    space = Literal.whitespace(min: 0)

    ignore(BaseTag.opening_tag())
    |> ignore(string("helper"))
    |> ignore(space)
    |> tag(Argument.argument(), :name)
    |> ignore(space)
    |> ignore(BaseTag.closing_tag())
  end

  @impl true
  def render([name: [value: helper_name]], %{counter_vars: %{"page" => %{"site" => site}}} = context, _options) do
    site = Beacon.Types.Atom.safe_to_atom(site)

    text =
      case Beacon.RuntimeRenderer.render_snippet_helper(site, helper_name, context.counter_vars) do
        {:ok, result} -> to_string(result)
        {:error, _} -> ""
      end

    {[text: text], context}
  end
end
