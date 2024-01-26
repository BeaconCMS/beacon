defmodule Beacon.Template.HEEx.TokenizerTest do
  use ExUnit.Case, async: true

  alias Beacon.Template.HEEx.Tokenizer

  test "inline expression" do
    assert Tokenizer.tokenize(~S|
      <%= user.name %>
    |) == {:ok, [{:eex, "user.name", %{line: 2, opt: ~c"=", column: 7}}]}
  end

  test "block expression" do
    assert Tokenizer.tokenize(~S|
      <%= if true do %>
        <p>this</p>
      <% else %>
        <p>that</p>
      <% end %>
    |) ==
             {:ok,
              [
                {:eex_block, "if true do",
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
                 ]}
              ]}
  end

  test "comprehension" do
    assert Tokenizer.tokenize(~S|
      <%= for employee <- @beacon_live_data[:employees] do %>
        <!-- regular <!-- comment --> -->
        <%= employee.position %>
        <div>
          <%= for person <- @beacon_live_data[:persons] do %>
            <%= if person.id == employee.id do %>
              <span><%= person.name %></span>
              <img src={if person.picture , do: person.picture, else: "default.jpg"} width="200" />
            <% end %>
          <% end %>
        </div>
      <% end %>
    |) == {
             :ok,
             [
               {
                 :eex_block,
                 "for employee <- @beacon_live_data[:employees] do",
                 [
                   {
                     [
                       {:html_comment, [{:text, "<!-- regular <!-- comment --> -->", %{}}]},
                       {:eex, "employee.position", %{column: 9, line: 4, opt: ~c"="}},
                       {:text, "\n        ", %{newlines: 1}},
                       {
                         :tag_block,
                         "div",
                         [],
                         [
                           {:text, "\n          ", %{newlines: 1}},
                           {:eex_block, "for person <- @beacon_live_data[:persons] do",
                            [
                              {[
                                 {:text, "\n            ", %{newlines: 1}},
                                 {:eex_block, "if person.id == employee.id do",
                                  [
                                    {[
                                       {:text, "\n              ", %{newlines: 1}},
                                       {:tag_block, "span", [], [{:eex, "person.name", %{column: 21, line: 8, opt: ~c"="}}], %{mode: :inline}},
                                       {:text, "\n              ", %{newlines: 1}},
                                       {:tag_self_close, "img",
                                        [
                                          {"src", {:expr, "if person.picture , do: person.picture, else: \"default.jpg\"", %{column: 25, line: 9}},
                                           %{column: 20, line: 9}},
                                          {"width", {:string, "200", %{delimiter: 34}}, %{column: 86, line: 9}}
                                        ]},
                                       {:text, "\n            ", %{newlines: 1}}
                                     ], "end"}
                                  ]},
                                 {:text, "\n          ", %{newlines: 1}}
                               ], "end"}
                            ]},
                           {:text, "\n        ", %{newlines: 1}}
                         ],
                         %{mode: :block}
                       },
                       {:text, "\n      ", %{newlines: 1}}
                     ],
                     "end"
                   }
                 ]
               }
             ]
           }
  end
end
