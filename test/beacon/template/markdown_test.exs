defmodule Beacon.Template.MarkdownTest do
  use ExUnit.Case, async: true

  alias Beacon.Template.Markdown

  test "convert to html" do
    expected = ~s|<h1>Test</h1>
<p>Paragraph</p>
<pre class="autumn highlight" style="background-color: #282C34; color: #ABB2BF;">
<code class="language-elixir" translate="no">
<span class="keyword" style="color: #E06C75;">defmodule</span> <span class="namespace" style="color: #61AFEF;">MyApp</span> <span class="keyword" style="color: #E06C75;">do</span>
  <span class="comment" style="font-style: italic; color: #5C6370;">@</span><span class="comment" style="font-style: italic; color: #5C6370;">moduledoc</span> <span class="comment" style="font-style: italic; color: #5C6370;">&quot;Test&quot;</span>

  <span class="keyword" style="color: #E06C75;">def</span> <span class="function" style="color: #61AFEF;">foo</span><span class="" style="color: #ABB2BF;">,</span> <span class="string" style="color: #98C379;">do: </span><span class="string" style="color: #98C379;">:bar</span>
<span class="keyword" style="color: #E06C75;">end</span>
</code></pre>
|

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
