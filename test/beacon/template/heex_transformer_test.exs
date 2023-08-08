defmodule Beacon.Template.HEEx.HeexTransformerTest do
  use ExUnit.Case, async: true

  alias Beacon.Template.HEEx.HeexTransformer

  test "tokenizes a complex template" do
    tokenization = [
      %{tag: "button", content: ["click me"], attrs: %{"class" => "big", "disabled" => true}},
      "\n",
      %{tag: ".link", content: ["Author (patch)"], attrs: %{"patch" => "/dev/authors/1-author"}},
      "\n",
      %{tag: "eex", content: "my_component(\"sample_component\", val: 1)", attrs: %{}},
      "\n",
      %{
        tag: "div",
        content: [
          "\n  ",
          %{
            tag: "BeaconWeb.Components.image_set",
            content: [],
            attrs: %{
              "asset" => "{@beacon_live_data[:img1]}",
              "self_close" => true,
              "sources" => "{[\"480w\"]}",
              "width" => "200px"
            }
          },
          "\n"
        ],
        attrs: %{}
      }
    ]

    heex_code = Phoenix.LiveView.HTMLFormatter.format(HeexTransformer.transform(tokenization), heex_line_length: 100)
    assert heex_code == """
    <button class="big" disabled>click me</button>
    <.link patch="/dev/authors/1-author">Author (patch)</.link>
    <%= my_component("sample_component", val: 1) %>
    <div>
      <BeaconWeb.Components.image_set asset={@beacon_live_data[:img1]} sources={["480w"]} width="200px" />
    </div>
    """
  end
end
