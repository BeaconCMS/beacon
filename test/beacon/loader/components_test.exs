defmodule Beacon.Loader.ComponentsTest do
  use Beacon.DataCase, async: false

  use Beacon.Test, site: :my_site
  alias Beacon.Loader

  defp render(rendered) do
    rendered
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  setup do
    Process.put(:beacon_site, default_site())
    :ok
  end

  test "load empty module without components" do
    {:ok, mod} = Loader.reload_components_module(default_site())
    assert mod.__info__(:functions) == [{:my_component, 1}, {:my_component, 2}]
  end

  test "body" do
    beacon_component_fixture(name: "hello", body: ~S|assigns = Map.put(assigns, :id, 1)|, template: ~S|<%= @id %>|)
    mod = Loader.fetch_components_module(default_site())
    assert render(mod.hello(%{})) == "1"
  end

  test "load component without attrs" do
    beacon_component_fixture(name: "hello", template: "<h1>hello</h1>")
    mod = Loader.fetch_components_module(default_site())
    assert render(mod.hello(%{})) == "<h1>hello</h1>"
  end

  describe "function component attrs types" do
    test "load component with string attrs" do
      beacon_component_fixture(
        name: "say_hello",
        template: "<h1>Hello <%= @first_name %> <%= @last_name %></h1>",
        attrs: [%{name: "first_name", type: "string"}, %{name: "last_name", type: "string"}]
      )

      mod = Loader.fetch_components_module(default_site())
      assert render(mod.say_hello(%{first_name: "José", last_name: "Valim"})) == "<h1>Hello José Valim</h1>"
    end

    test "load component with boolean attr" do
      beacon_component_fixture(
        name: "say_hello",
        template: """
        <h1>Hello <%= @first_name %></h1>
        <h2 :if={@ask_question?}>What's up?</h2>
        """,
        attrs: [%{name: "first_name", type: "string"}, %{name: "ask_question?", type: "boolean"}]
      )

      mod = Loader.fetch_components_module(default_site())

      assert render(mod.say_hello(%{first_name: "José", ask_question?: true})) ==
               """
               <h1>Hello José</h1>
               <h2>What's up?</h2>
               """
               |> String.replace_suffix("\n", "")

      assert render(mod.say_hello(%{first_name: "José", ask_question?: false})) == """
             <h1>Hello José</h1>
             """
    end

    test "load component with integer attr" do
      beacon_component_fixture(
        name: "show_versions",
        template: """
        <p>Erlang version: <%= @erl_version %></p>
        <p>Elixir version: <%= @elixir_version %></p>
        """,
        attrs: [%{name: "erl_version", type: "integer"}, %{name: "elixir_version", type: "float"}]
      )

      mod = Loader.fetch_components_module(default_site())

      assert render(mod.show_versions(%{erl_version: 26, elixir_version: 1.16})) ==
               """
               <p>Erlang version: 26</p>
               <p>Elixir version: 1.16</p>
               """
               |> String.replace_suffix("\n", "")
    end

    test "load component with atom attr" do
      beacon_component_fixture(
        name: "say_hello",
        template: "<p><%= @greeting %>!</p>",
        attrs: [%{name: "greeting", type: "atom"}]
      )

      mod = Loader.fetch_components_module(default_site())
      assert render(mod.say_hello(%{greeting: :hello})) == "<p>hello!</p>"
    end

    test "load component with list attr" do
      beacon_component_fixture(
        name: "advice",
        template: """
        <p>Some good programming languages:</p>
        <ul>
          <li :for={lang <- @langs}><%= lang %></li>
        </ul>
        """,
        attrs: [%{name: "langs", type: "list"}]
      )

      mod = Loader.fetch_components_module(default_site())

      assert render(mod.advice(%{langs: ["Erlang", "Elixir", "Rust"]})) ==
               """
               <p>Some good programming languages:</p>
               <ul>
                 <li>Erlang</li><li>Elixir</li><li>Rust</li>
               </ul>
               """
               |> String.replace_suffix("\n", "")
    end

    test "load component with map attr" do
      beacon_component_fixture(
        name: "user_info",
        template: """
        <%= @user.name %>:<%= @user.age %>
        """,
        attrs: [%{name: "user", type: "map"}]
      )

      mod = Loader.fetch_components_module(default_site())

      assert render(mod.user_info(%{user: %{name: "Joe", age: 20}})) == "Joe:20"
    end

    test "load component with struct attrs" do
      beacon_component_fixture(
        name: "render_component_site",
        template: "<h1>Component site: <%= @component.site %></h1>",
        attrs: [%{name: "component", type: "struct", struct_name: "Beacon.Content.Component"}]
      )

      mod = Loader.fetch_components_module(default_site())
      assert render(mod.render_component_site(%{component: %Beacon.Content.Component{site: :dy}})) == "<h1>Component site: dy</h1>"
    end

    test "load component with function attr" do
      beacon_component_fixture(
        name: "say_hello",
        template: "<h1>Hello <%= @first_name %> <%= @fn_last_name.('test') %></h1>",
        attrs: [%{name: "first_name", type: "string"}, %{name: "fn_last_name", type: "any"}]
      )

      mod = Loader.fetch_components_module(default_site())
      assert render(mod.say_hello(%{first_name: "José", fn_last_name: fn x -> "FnValim #{x}" end})) == "<h1>Hello José FnValim test</h1>"
    end
  end

  describe "function component options" do
    test "load component with options: required and default" do
      beacon_component_fixture(
        name: "say_hello",
        template: "<h1>Hello <%= @first_name %> <%= @last_name %></h1>",
        attrs: [
          %{name: "first_name", type: "string", opts: [required: true]},
          %{name: "last_name", type: "string", opts: [default: "Doe"]}
        ]
      )

      mod = Loader.fetch_components_module(default_site())
      assert render(mod.say_hello(%{first_name: "Jane"})) == "<h1>Hello Jane Doe</h1>"
      assert render(mod.say_hello(%{first_name: "Jane", last_name: "Foo Bar"})) == "<h1>Hello Jane Foo Bar</h1>"

      assert_raise KeyError, ~r/^key :first_name not found in:/, fn ->
        render(mod.say_hello(%{}))
      end
    end

    test "load component with options: values and doc" do
      beacon_component_fixture(
        name: "error_message",
        template: "<h1 class={@kind}>Failed Operation</h1>",
        attrs: [
          %{name: "kind", type: "atom", opts: [values: [:info, :error], doc: "test function component doc"]}
        ]
      )

      mod = Loader.fetch_components_module(default_site())
      assert render(mod.error_message(%{kind: :info})) == "<h1 class=\"info\">Failed Operation</h1>"
      assert render(mod.error_message(%{kind: :error})) == "<h1 class=\"error\">Failed Operation</h1>"
    end
  end

  describe "slots" do
    # same example as https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#module-the-default-slot
    test "load component using the default slot" do
      beacon_component_fixture(
        name: "unordered_list",
        template: """
        <ul>
          <%= for entry <- @entries do %>
            <li><%= render_slot(@inner_block, entry) %></li>
          <% end %>
        </ul>
        """,
        slots: [
          %{name: "inner_block", opts: [required: true]}
        ],
        attrs: [%{name: "entries", type: "list", opts: [default: []]}]
      )

      mod = Loader.fetch_components_module(default_site())

      assert render(
               mod.unordered_list(%{
                 entries: ~w(apples bananas cherries),
                 inner_block: [%{inner_block: fn _, fruit -> Phoenix.HTML.raw("I like <b>#{fruit}</b>!") end}]
               })
             ) ==
               "<ul>\n\n    <li>I like <b>apples</b>!</li>\n\n    <li>I like <b>bananas</b>!</li>\n\n    <li>I like <b>cherries</b>!</li>\n\n</ul>"
    end

    # same example as https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#module-named-slots
    test "load component using named slots" do
      beacon_component_fixture(
        name: "modal",
        template: """
        <div class="modal">
          <div class="modal-header">
            <%= render_slot(@header) || "Modal" %>
          </div>
          <div class="modal-body">
            <%= render_slot(@inner_block) %>
          </div>
          <div class="modal-footer">
            <%= render_slot(@footer) %>
          </div>
        </div>
        """,
        slots: [
          %{name: "header"},
          %{name: "inner_block", opts: [required: true]},
          %{name: "footer", opts: [required: true]}
        ]
      )

      mod = Loader.fetch_components_module(default_site())

      assert render(
               mod.modal(%{
                 inner_block: %{inner_block: fn _, _ -> "This is the body, everything not in a named slot is rendered in the default slot." end},
                 footer: %{inner_block: fn _, _ -> "This is the bottom of the modal." end}
               })
             ) ==
               "<div class=\"modal\">\n  <div class=\"modal-header\">\nModal\n  </div>\n  <div class=\"modal-body\">\nThis is the body, everything not in a named slot is rendered in the default slot.\n  </div>\n  <div class=\"modal-footer\">\nThis is the bottom of the modal.\n  </div>\n</div>"
    end

    # same example as https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#module-slot-attributes
    test "load component using slot attributes" do
      beacon_component_fixture(
        name: "table",
        template: """
        <table>
          <tr>
            <%= for col <- @column do %>
              <th><%= col.label %></th>
            <% end %>
          </tr>
          <%= for row <- @rows do %>
            <tr>
              <%= for col <- @column do %>
                <td><%= render_slot(col, row) %></td>
              <% end %>
            </tr>
          <% end %>
        </table>
        """,
        slots: [
          %{
            name: "column",
            opts: [doc: "Columns with column labels"],
            attrs: [%{name: "label", type: "string", opts: [required: true, doc: "Column label"]}]
          }
        ],
        attrs: [%{name: "rows", type: "list", opts: [default: []]}]
      )

      mod = Loader.fetch_components_module(default_site())

      assert render(
               mod.table(%{
                 rows: [%{name: "Jane", age: "34"}, %{name: "Bob", age: "51"}],
                 column: [
                   %{label: "Name", inner_block: fn _, user -> "#{user.name}" end},
                   %{label: "Age", inner_block: fn _, user -> "#{user.age}" end}
                 ]
               })
             ) ==
               "<table>\n  <tr>\n\n      <th>Name</th>\n\n      <th>Age</th>\n\n  </tr>\n\n    <tr>\n\n        <td>Jane</td>\n\n        <td>34</td>\n\n    </tr>\n\n    <tr>\n\n        <td>Bob</td>\n\n        <td>51</td>\n\n    </tr>\n\n</table>"
    end
  end
end
