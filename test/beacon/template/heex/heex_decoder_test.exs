defmodule Beacon.Template.HEEx.HEExDecoderTest do
  use Beacon.DataCase

  alias Beacon.Template.HEEx.HEExDecoder
  alias Beacon.Template.HEEx.JSONEncoder
  use Beacon.Test

  defp assert_equal(input, assigns \\ %{}, site \\ :my_site) do
    assert {:ok, encoded} = JSONEncoder.encode(site, input, assigns)
    decoded = HEExDecoder.decode(encoded)
    assert String.trim(decoded) == String.trim(input)
  end

  test "html elements with attrs" do
    assert_equal(~S|<div>content</div>|)
    assert_equal(~S|<a href="/contact">contact</a>|)
    assert_equal(~S|<span class="bg-red text-sm">warning</span>|)
  end

  test "comments" do
    assert_equal(~S|<!-- comment -->|)

    if Version.match?(System.version(), ">= 1.15.0") do
      assert_equal(~S|<%!-- comment --%>|)
      assert_equal(~S|<%!-- <%= expr %> --%>|)
    end
  end

  test "eex expressions" do
    assert_equal(~S|{_a = true}|)
    assert_equal(~S|value: {1}|)
    assert_equal(~S|{_a = 1}|)
  end

  test "eex blocks" do
    assert_equal(
      ~S"""
      <%= if @completed do %>
        congrats
      <% else %>
        keep working
      <% end %>
      """,
      %{completed: true}
    )

    assert_equal(
      ~S"""
      <%= case @completed do %>
        <% true -> %>
          congrats
      <% end %>
      """,
      %{completed: true}
    )

    assert_equal(
      ~S"""
      <%= for val <- @vals do %>
        {val}
      <% end %>
      """,
      %{vals: [1]}
    )
  end

  describe "components" do
    test "phoenix components" do
      assert_equal(~S|<.link path="/contact" replace={true}>Book meeting</.link>|)
    end

    test "beacon components" do
      beacon_component_fixture(name: "heex_test")
      assert_equal(~S|<.heex_test class="w-4" val="test" />|)
    end

    test "with special attribute :let" do
      template = ~S"""
      <Phoenix.Component.form :let={f} as={:newsletter} for={%{}} phx-submit="join">
        <input
          class="text-sm"
          id={Phoenix.HTML.Form.input_id(f, :email)}
          name={Phoenix.HTML.Form.input_name(f, :email)}
          placeholder="Enter your email"
          type="email"
        /><button type="submit">Join</button>
      </Phoenix.Component.form>
      """

      assert_equal(template)
    end

    test "with :slot" do
      beacon_component_fixture(
        name: "table",
        attrs: [
          %{name: "id", type: "string", opts: [required: true]},
          %{name: "rows", type: "list", opts: [required: true]},
          %{name: "row_id", type: "any", opts: [default: nil]},
          %{name: "row_item", type: "any", opts: [default: &Function.identity/1]}
        ],
        slots: [
          %{
            name: "col",
            opts: [required: true],
            attrs: [%{name: "label", type: "string"}]
          }
        ],
        template: """
        <div>
          <table>
            <thead>
              <tr>
                <th :for={col <- @col}><%= col[:label] %></th>
              </tr>
            </thead>
            <tbody id={@id}>
              <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
                <td :for={col <- @col}>
                  <div>
                    <span>
                      <%= render_slot(col, @row_item.(row)) %>
                    </span>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        """
      )

      assert_equal(~S"""
      <.table id="users" rows={[%{id: 1, username: "foo"}]}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
      """)
    end

    test "nested in slot" do
      beacon_component_fixture(
        name: "html_tag",
        attrs: [
          %{name: "name", type: "string", opts: [required: true]}
        ],
        slots: [
          %{name: "inner_block", opts: [required: true]}
        ],
        template: ~S|<.dynamic_tag tag_name={@name}><%= render_slot(@inner_block) %></.dynamic_tag>|,
        example: ~S|<.html_tag name="p">content</.tag>|
      )

      assert_equal(~S"""
      <.html_tag name="div">
        <.html_tag name="span">nested</.html_tag>
      </.html_tag>
      """)
    end
  end

  test "live data assigns" do
    assert_equal(~S|{@name}|, %{name: "Beacon"})
  end

  test "script tag" do
    assert_equal(~S"""
    <script data-domain={MyAppWeb.Endpoint.config(:url)[:host]} defer src="/js/script.js">
    </script>
    """)
  end
end
