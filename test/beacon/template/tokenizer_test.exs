defmodule Beacon.Template.HEEx.TokenizerTest do
  use ExUnit.Case, async: true

  alias Beacon.Template.HEEx.Tokenizer

  test "tokenizes a complex template" do
    template = ~S|
    <section>
      <p><%= user.name %></p>
      <%= if true do %>
        <p>this</p>
      <% else %>
        <p>that</p>
      <% end %>
    </section>
    <BeaconWeb.Components.image_set asset={@beacon_live_data[:img1]} sources={["480w"]} width="200px" />
    |

    assert {:ok, result} = Tokenizer.tokenize(template)

    assert result ==
             [
               {
                 :tag_block,
                 "section",
                 [],
                 [
                   {:text, "\n      ", %{newlines: 1}},
                   {:tag_block, "p", [], [{:eex, "user.name", %{column: 10, line: 3, opt: ~c"="}}], %{mode: :block}},
                   {:text, "\n      ", %{newlines: 1}},
                   {
                     :eex_block,
                     "if true do",
                     [
                       {[
                          {:text, "\n        ", %{newlines: 1}},
                          {:tag_block, "p", [], [{:text, "this", %{newlines: 0}}], %{mode: :block}},
                          {:text, "\n      ", %{newlines: 1}}
                        ], "else"},
                       {[
                          {:text, "\n        ", %{newlines: 1}},
                          {:tag_block, "p", [], [{:text, "that", %{newlines: 0}}], %{mode: :block}},
                          {:text, "\n      ", %{newlines: 1}}
                        ], "end"}
                     ]
                   },
                   {:text, "\n    ", %{newlines: 1}}
                 ],
                 %{mode: :block}
               },
               {:text, "\n    ", %{newlines: 1}},
               {
                 :tag_self_close,
                 "BeaconWeb.Components.image_set",
                 [
                   {"asset", {:expr, "@beacon_live_data[:img1]", %{column: 44, line: 10}}, %{column: 37, line: 10}},
                   {"sources", {:expr, "[\"480w\"]", %{column: 79, line: 10}}, %{column: 70, line: 10}},
                   {"width", {:string, "200px", %{delimiter: 34}}, %{column: 89, line: 10}}
                 ]
               }
             ]
  end
end
