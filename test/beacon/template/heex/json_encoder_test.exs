defmodule Beacon.Template.HEEx.JSONEncoderTest do
  use Beacon.DataCase

  alias Beacon.Template.HEEx.JSONEncoder
  import Beacon.Fixtures

  defp assert_output(template, expected, assigns \\ %{}, site \\ :my_site) do
    assert {:ok, encoded} = JSONEncoder.encode(site, template, assigns)
    assert encoded == expected
  end

  test "html elements with attrs" do
    assert_output(~S|<div>content</div>|, [%{"attrs" => %{}, "content" => ["content"], "tag" => "div"}])
    assert_output(~S|<a href="/contact">contact</a>|, [%{"attrs" => %{"href" => "/contact"}, "content" => ["contact"], "tag" => "a"}])

    assert_output(~S|<span class="bg-red text-sm">warning</span>|, [
      %{"attrs" => %{"class" => "bg-red text-sm"}, "content" => ["warning"], "tag" => "span"}
    ])
  end

  test "nested elements" do
    assert_output(
      ~S|<div><span>content</span></div>|,
      [
        %{
          "attrs" => %{},
          "content" => [%{"attrs" => %{}, "content" => ["content"], "tag" => "span"}],
          "tag" => "div"
        }
      ]
    )
  end

  test "comments" do
    assert_output(~S|<!-- comment -->|, [%{"attrs" => %{}, "content" => [" comment "], "tag" => "html_comment"}])
    assert_output(~S|<%!-- comment --%>|, [%{"attrs" => %{}, "content" => [" comment "], "tag" => "eex_comment"}])
    assert_output(~S|<%!-- <%= :expr %> --%>|, [%{"attrs" => %{}, "content" => [" <%= :expr %> "], "tag" => "eex_comment"}])
  end

  test "eex expressions" do
    assert_output(~S|value: <%= 1 %>|, ["value: ", %{"attrs" => %{}, "content" => ["1"], "rendered_html" => "1", "tag" => "eex"}])

    assert_output(
      ~S"""
      <%= if @completed do %>
        <div><span><%= @completed_message %></span></div>
      <% else %>
        Keep working
      <% end %>
      """,
      [
        %{
          "arg" => "if @completed do",
          "blocks" => [
            %{
              "content" => [
                %{
                  "attrs" => %{},
                  "content" => [
                    %{
                      "attrs" => %{},
                      "content" => [%{"attrs" => %{}, "content" => ["@completed_message"], "rendered_html" => "Congrats", "tag" => "eex"}],
                      "tag" => "span"
                    }
                  ],
                  "tag" => "div"
                }
              ],
              "key" => "else"
            },
            %{"content" => ["Keep working"], "key" => "end"}
          ],
          "tag" => "eex_block"
        }
      ],
      %{completed_message: "Congrats"}
    )

    assert_output(
      ~S"""
      <%= case @users do %>
      <% users when is_list(users) -> %>
        <%= if length(users) == 1 do %>
          <div>Only 1 found</div>
        <% else %>
          <div>Multiple users found</div>
        <% end %>
      <% :error -> %>
        <div>Not Found</div>
      <% _ -> %>
        <div>Something went wrong</div>
      <% end %>
      """,
      [
        %{
          "arg" => "case @users do",
          "blocks" => [
            %{"content" => [], "key" => "users when is_list(users) ->"},
            %{
              "content" => [
                %{
                  "tag" => "eex_block",
                  "arg" => "if length(users) == 1 do",
                  "blocks" => [
                    %{"content" => [%{"attrs" => %{}, "content" => ["Only 1 found"], "tag" => "div"}], "key" => "else"},
                    %{"content" => [%{"attrs" => %{}, "content" => ["Multiple users found"], "tag" => "div"}], "key" => "end"}
                  ]
                }
              ],
              "key" => ":error ->"
            },
            %{
              "content" => [%{"attrs" => %{}, "content" => ["Not Found"], "tag" => "div"}],
              "key" => "_ ->"
            },
            %{
              "content" => [
                %{"attrs" => %{}, "content" => ["Something went wrong"], "tag" => "div"}
              ],
              "key" => "end"
            }
          ],
          "tag" => "eex_block"
        }
      ]
    )
  end

  test "function components" do
    assert_output(
      ~S|<BeaconWeb.Components.image name="logo.jpg" width="200px" />|,
      [
        %{"attrs" => %{"name" => "logo.jpg", "self_close" => true, "width" => "200px"}, "content" => [], "tag" => "BeaconWeb.Components.image"}
      ]
    )

    assert_output(
      ~S|<.link path="/contact" replace={true}>Book meeting</.link>|,
      [
        %{
          "attrs" => %{"path" => "/contact", "replace" => "{true}"},
          "content" => ["Book meeting"],
          "rendered_html" => "<a href=\"#\" path=\"/contact\">Book meeting</a>",
          "tag" => ".link"
        }
      ]
    )
  end

  test "my_component" do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
    component_fixture(site: :my_site)
    Beacon.Loader.load_components(:my_site)

    assert_output(
      ~S|<%= my_component("sample_component", %{val: 1}) %>|,
      [
        %{
          "attrs" => %{},
          "content" => ["my_component(\"sample_component\", %{val: 1})"],
          "rendered_html" => "<span id=\"my-component-1\">1</span>",
          "tag" => "eex"
        }
      ]
    )
  end

  test "assigns" do
    assert_output(
      ~S|<%= @project.name %>|,
      [%{"attrs" => %{}, "content" => ["@project.name"], "rendered_html" => "Beacon", "tag" => "eex"}],
      %{project: %{name: "Beacon"}}
    )
  end

  test "invalid template" do
    assert_raise Beacon.ParserError, fn ->
      JSONEncoder.encode(:my_site, ~S|<%= :error|)
    end
  end
end
