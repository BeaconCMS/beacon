defmodule Beacon.Template.HEEx.TokenizerTest do
  use ExUnit.Case, async: true

  alias Beacon.Template.HEEx.Tokenizer

  test "tokenizes a complex template" do
    {:ok, result} =
      Tokenizer.tokenize(
        ~s(<section>\n  <p><%= user.name %></p>\n  <%= if true do %> <p>this</p><% else %><p>that</p><% end %>\n</section>\n<BeaconWeb.Components.image_set asset={@beacon_live_data[:img1]} sources={["480w"]} width="200px" />)
      )

    assert result ==
             [
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
  end
end
