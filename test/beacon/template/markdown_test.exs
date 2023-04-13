defmodule Beacon.Template.MarkdownTest do
  use ExUnit.Case, async: true

  alias Beacon.Template.Markdown

  test "convert to html" do
    assert Markdown.convert_to_html(
             """
             # Test

             New line
             """,
             %{}
           ) == {:cont, "<h1>Test</h1>\n<p>New line</p>\n"}
  end
end
