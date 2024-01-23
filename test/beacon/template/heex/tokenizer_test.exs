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
      <%= for val <- @beacon_live_data[:vals] do %>
        <%= val %>
      <% end %>
    |) ==
             {:ok,
              [
                {:eex_block, "for val <- @beacon_live_data[:vals] do",
                 [
                   {[
                      {:text, "\n        ", %{newlines: 1}},
                      {:eex, "val", %{line: 3, opt: ~c"=", column: 9}},
                      {:text, "\n      ", %{newlines: 1}}
                    ], "end"}
                 ]}
              ]}
  end
end
