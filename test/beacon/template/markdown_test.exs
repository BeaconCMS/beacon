defmodule Beacon.Template.MarkdownTest do
  use ExUnit.Case, async: true

  alias Beacon.Template.Markdown

  test "convert to html" do
    expected = """
    <h1>Test</h1>
    <p>Paragraph</p>
    <pre class="autumn-hl" style="background-color: #282C34; color: #ABB2BF;"><code class="language-elixir" translate="no"><span class="ahl-keyword" style="color: #E06C75;">defmodule</span> <span class="ahl-namespace" style="color: #61AFEF;">MyApp</span> <span class="ahl-keyword" style="color: #E06C75;">do</span>
      <span class="ahl-comment ahl-block ahl-documentation" style="font-style: italic; color: #5C6370;">@</span><span class="ahl-comment ahl-block ahl-documentation" style="font-style: italic; color: #5C6370;">moduledoc</span> <span class="ahl-comment ahl-block ahl-documentation" style="font-style: italic; color: #5C6370;">&quot;Test&quot;</span>

      <span class="ahl-keyword" style="color: #E06C75;">def</span> <span class="ahl-function" style="color: #61AFEF;">foo</span><span class="ahl-punctuation ahl-delimiter" style="color: #ABB2BF;">,</span> <span class="ahl-string ahl-special ahl-symbol" style="color: #98C379;">do: </span><span class="ahl-string ahl-special ahl-symbol" style="color: #98C379;">:bar</span>
    <span class="ahl-keyword" style="color: #E06C75;">end</span>
    </code></pre>
    """

    assert Markdown.convert_to_html(
             """
             # Test

             Paragraph

             ```elixir
             defmodule MyApp do
               @moduledoc "Test"

               def foo, do: :bar
             end
             ```
             """,
             %{}
           ) == {:cont, expected}
  end
end
