defmodule Beacon.Template.HEEx.HeexTransformerTest do
  use ExUnit.Case, async: true

  alias Beacon.Template.HEEx.HeexTransformer

  test "transforms a complex ast" do
    json_ast = [
      %{"tag" => "button", "content" => ["click me"], "attrs" => %{"class" => "big", "disabled" => true}},
      %{"tag" => ".link", "content" => ["Author (patch)"], "attrs" => %{"patch" => "/dev/authors/1-author"}},
      %{"tag" => "eex", "content" => "my_component(\"sample_component\", val: 1)", "attrs" => %{}},
      %{
        "tag" => "div",
        "content" => [
          %{
            "tag" => "BeaconWeb.Components.image_set",
            "content" => [],
            "attrs" => %{
              "asset" => "{@beacon_live_data[:img1]}",
              "self_close" => true,
              "sources" => "{[\"480w\"]}",
              "width" => "200px"
            }
          }
        ],
        "attrs" => %{}
      }
    ]

    # heex_code = Phoenix.LiveView.HTMLFormatter.format(HeexTransformer.transform(json_ast), heex_line_length: 100)
    heex_code = HeexTransformer.transform(json_ast)

    assert heex_code == ~s|<button class="big" disabled>click me</button><.link patch="/dev/authors/1-author">Author (patch)</.link><%=my_component("sample_component", val: 1)%><div><BeaconWeb.Components.image_set asset={@beacon_live_data[:img1]} sources={["480w"]} width="200px"/></div>|
  end
end
