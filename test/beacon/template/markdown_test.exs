defmodule Beacon.Template.MarkdownTest do
  use ExUnit.Case, async: true

  alias Beacon.Template.Markdown

  test "convert to html" do
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
           ) ==
             {:cont,
              "<h1>Test</h1>\n<p>Paragraph</p>\n<pre style=\"background-color:#282a36;\"><code class=\"language-elixir\"><span style=\"color:#ff79c6;\">defmodule </span><span style=\"text-decoration:underline;color:#8be9fd;\">MyApp </span><span style=\"color:#ff79c6;\">do\n</span><span style=\"color:#f8f8f2;\">  </span><span style=\"color:#6272a4;\">@moduledoc &quot;Test&quot;\n</span><span style=\"color:#f8f8f2;\">\n</span><span style=\"color:#f8f8f2;\">  </span><span style=\"color:#ff79c6;\">def </span><span style=\"color:#50fa7b;\">foo</span><span style=\"color:#f8f8f2;\">, </span><span style=\"color:#bd93f9;\">do: :bar\n</span><span style=\"color:#ff79c6;\">end\n</span></code></pre>\n"}
  end
end
