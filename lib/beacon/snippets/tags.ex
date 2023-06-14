defmodule Beacon.Snippets.Tags.Helper do
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
    site = Beacon.Types.Site.safe_to_atom(site)
    helper_name = String.to_atom(helper_name)

    text =
      site
      |> Beacon.Loader.snippet_helpers_module_for_site()
      |> Beacon.Loader.call_function_with_retry(helper_name, [context.counter_vars])
      |> to_string()

    {[text: text], context}
  end
end
