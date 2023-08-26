defmodule Beacon.Template.HEEx.JSONEncoderTest do
  use Beacon.DataCase

  alias Beacon.Template.HEEx.JSONEncoder
  import Beacon.Fixtures

  defp assert_output(template, expected, site \\ :my_site) do
    assert {:ok, encoded} = JSONEncoder.encode(template, site)
    assert encoded == expected
  end

  test "html elements with attrs" do
    assert_output(~S|<div>content</div>|, [%{"attrs" => %{}, "content" => ["content"], "tag" => "div"}])
    assert_output(~S|<a href="/contact">contact</a>|, [%{"attrs" => %{"href" => "/contact"}, "content" => ["contact"], "tag" => "a"}])

    assert_output(~S|<span class="bg-red text-sm">warning</span>|, [
      %{"attrs" => %{"class" => "bg-red text-sm"}, "content" => ["warning"], "tag" => "span"}
    ])
  end

  test "comments" do
    assert_output(~S|<%!-- comment --%>|, [%{"attrs" => %{}, "content" => [" comment "], "tag" => "eex_comment"}])
  end

  test "eex expressions" do
    assert_output(~S|value: <%= 1 %>|, ["value: ", %{"attrs" => %{}, "content" => ["1"], "rendered_html" => "1", "tag" => "eex"}])

    assert_output(
      ~S"""
      <%= if @completed do %>
      Congrats
      <% else %>
      Keep working
      <% end %>
      """,
      [
        %{
          "arg" => "if @completed do",
          "blocks" => [%{"content" => ["Congrats"], "key" => "else"}, %{"content" => ["Keep working"], "key" => "end"}],
          "tag" => "eex_block"
        }
      ]
    )

    assert_output(
      ~S"""
      <%= case @users do %>
      <% users when is_list(users) -> %>
        <div>Users</div>
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
            %{"content" => [%{"attrs" => %{}, "content" => ["Users"], "tag" => "div"}], "key" => ":error ->"},
            %{"content" => [%{"attrs" => %{}, "content" => ["Not Found"], "tag" => "div"}], "key" => "_ ->"},
            %{"content" => [%{"attrs" => %{}, "content" => ["Something went wrong"], "tag" => "div"}], "key" => "end"}
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

  test "beacon_live_data assigns" do
    assert_output(
      ~S|<%= @beacon_live_data[:todo] %>|,
      [
        %{"attrs" => %{}, "content" => ["@beacon_live_data[:todo]"], "rendered_html" => "", "tag" => "eex"}
      ]
    )
  end

  test "invalid template" do
    assert_raise Beacon.ParserError, fn ->
      JSONEncoder.encode(~S|<%= :error|, :my_site)
    end
  end
end
