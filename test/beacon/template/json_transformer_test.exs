defmodule Beacon.Template.HEEx.JsonTransformerTest do
  use ExUnit.Case, async: true

  alias Beacon.Template.HEEx.JsonTransformer

  test "transforms a complex tokenization" do
    tokenization = [
      {
        :tag_block,
        "section",
        [],
        [
          {:text, "\n  ", %{newlines: 1}},
          {
            :tag_block,
            "p",
            [],
            [{:eex, "user.name", %{column: 6, line: 2, opt: ~c"="}}],
            %{mode: :block}
          },
          {:text, "\n  ", %{newlines: 1}},
          {
            :eex_block,
            "if true do",
            [
              {
                [
                  {:text, " ", %{newlines: 0}},
                  {:tag_block, "p", [], [{:text, "this", %{newlines: 0}}], %{mode: :block}}
                ],
                "else"
              },
              {[{:tag_block, "p", [], [{:text, "that", %{newlines: 0}}], %{mode: :block}}], "end"}
            ]
          },
          {:text, "\n", %{newlines: 1}}
        ],
        %{mode: :block}
      },
      {:text, "\n", %{newlines: 1}},
      {:tag_self_close, "BeaconWeb.Components.image_set",
       [
         {"asset", {:expr, "@beacon_live_data[:img1]", %{column: 40, line: 5}}, %{column: 33, line: 5}},
         {"sources", {:expr, "[\"480w\"]", %{column: 75, line: 5}}, %{column: 66, line: 5}},
         {"width", {:string, "200px", %{delimiter: 34}}, %{column: 85, line: 5}}
       ]}
    ]

    assert JsonTransformer.transform(tokenization) ==
             [
               %{
                 "attrs" => %{},
                 "content" => [
                   %{"attrs" => %{}, "content" => [%{"attrs" => %{}, "content" => "user.name", "tag" => "eex"}], "tag" => "p"},
                   %{
                     "arg" => "if true do",
                     "blocks" => [
                       %{"content" => [%{"attrs" => %{}, "content" => ["this"], "tag" => "p"}], "key" => "else"},
                       %{"content" => [%{"attrs" => %{}, "content" => ["that"], "tag" => "p"}], "key" => "end"}
                     ],
                     "tag" => "eex_block"
                   }
                 ],
                 "tag" => "section"
               },
               %{
                 "tag" => "BeaconWeb.Components.image_set",
                 "attrs" => %{"self_close" => true, "asset" => "{@beacon_live_data[:img1]}", "sources" => "{[\"480w\"]}", "width" => "200px"},
                 "content" => []
               }
             ]
  end

  test "tokenizes a template with an eex_block with more than two paths" do
    tokenization = [
      {:eex_block, "case @status do",
       [
         {[{:text, "\n", %{newlines: 1}}], ":completed ->"},
         {[
            {:text, " ", %{newlines: 0}},
            {:tag_block, "span", [{"class", {:string, "text-lg", %{delimiter: 34}}, %{line: 2, column: 27}}],
             [{:text, "Completed", %{mode: :normal, newlines: 0}}], %{mode: :inline}},
            {:text, "\n", %{newlines: 1}}
          ], ":pending ->"},
         {[{:text, "Pending\n", %{newlines: 0}}], "_ ->"},
         {[{:text, "Undefined\n", %{newlines: 0}}], "end"}
       ]}
    ]

    assert JsonTransformer.transform(tokenization) ==
             [
               %{
                 "tag" => "eex_block",
                 "arg" => "case @status do",
                 "blocks" => [
                   %{"key" => ":completed ->", "content" => []},
                   %{
                     "key" => ":pending ->",
                     "content" => [%{"tag" => "span", "content" => ["Completed"], "attrs" => %{"class" => "text-lg"}}]
                   },
                   %{"key" => "_ ->", "content" => ["Pending"]},
                   %{"key" => "end", "content" => ["Undefined"]}
                 ]
               }
             ]
  end

  test "includes the rendered HTML for phoenix function components" do
    tokenization =  [
      {:tag_block, ".link",
       [
         {"patch", {:string, "/contact", %{delimiter: 34}}, %{line: 1, column: 8}},
         {"replace", {:expr, "true", %{line: 1, column: 34}}, %{line: 1, column: 25}}
       ], [{:text, "Sample text", %{mode: :normal, newlines: 0}}], %{mode: :inline}}
    ]

    assert JsonTransformer.transform(tokenization) ==
      [
        %{
          "attrs" => %{"patch" => "/contact", "replace" => "{true}"},
          "content" => ["Sample text"],
          "rendered_html" => ~S|<a href="/contact" data-phx-link="patch" data-phx-link-state="replace">Sample text</a>|,
          "tag" => ".link"
        }
      ]

  end
end
