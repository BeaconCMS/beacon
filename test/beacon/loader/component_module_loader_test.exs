defmodule Beacon.Loader.ComponentModuleLoaderTest do
  use Beacon.DataCase, async: false

  import Beacon.Fixtures
  alias Beacon.Content
  alias Beacon.Loader.ComponentModuleLoader

  @site :my_site

  defp render(rendered) do
    rendered
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(@site)})
    :ok
  end

  @tag :skip
  test "load empty module without components" do
    {:ok, mod} = ComponentModuleLoader.load_components(@site, [])
    assert mod.__info__(:functions) == [{:__components__, 0}]
  end

  @tag :skip
  test "inject beacon site into assigns" do
    component_fixture(name: "hello", body: "<%= @beacon_site %>")
    components = Content.list_components(@site, per_page: :infinity)

    {:ok, mod} = ComponentModuleLoader.load_components(@site, components)
    assert render(mod.hello(%{})) == "my_site"
  end

  test "load component without attrs" do
    component_fixture(name: "hello", body: "<h1>Hello</h1>")
    components = Content.list_components(@site, per_page: :infinity, preloads: [:attrs])

    {:ok, mod} = ComponentModuleLoader.load_components(@site, components)
    assert render(mod.hello(%{})) == "<h1>Hello</h1>"
  end

  describe "function component attrs types" do
    test "load component with string attrs" do
      component_fixture(
        name: "say_hello",
        body: "<h1>Hello <%= @first_name %> <%= @last_name %></h1>",
        attrs: [%{name: "first_name", type: "string"}, %{name: "last_name", type: "string"}]
      )

      components = Content.list_components(@site, per_page: :infinity, preloads: [:attrs])

      {:ok, mod} = ComponentModuleLoader.load_components(@site, components)
      assert render(mod.say_hello(%{first_name: "José", last_name: "Valim"})) == "<h1>Hello José Valim</h1>"
    end

    test "load component with boolean attr" do
      component_fixture(
        name: "say_hello",
        body: """
        <h1>Hello <%= @first_name %></h1>
        <h2 :if={@ask_question?}>What's up?</h2>
        """,
        attrs: [%{name: "first_name", type: "string"}, %{name: "ask_question?", type: "boolean"}]
      )

      components = Content.list_components(@site, per_page: :infinity, preloads: [:attrs])

      {:ok, mod} = ComponentModuleLoader.load_components(@site, components)
      assert render(mod.say_hello(%{first_name: "José", ask_question?: true})) == "<h1>Hello José</h1>\n<h2>What's up?</h2>"
      assert render(mod.say_hello(%{first_name: "José", ask_question?: false})) == "<h1>Hello José</h1>\n"
    end

    test "load component with integer attr" do
      component_fixture(
        name: "show_versions",
        body: """
        <p>Erlang version: <%= @erl_version %></p>
        <p>Elixir version: <%= @elixir_version %></p>
        """,
        attrs: [%{name: "erl_version", type: "integer"}, %{name: "elixir_version", type: "float"}]
      )

      components = Content.list_components(@site, per_page: :infinity, preloads: [:attrs])

      {:ok, mod} = ComponentModuleLoader.load_components(@site, components)
      assert render(mod.show_versions(%{erl_version: 26, elixir_version: 1.16})) == "<p>Erlang version: 26</p>\n<p>Elixir version: 1.16</p>"
    end

    test "load component with atom attr" do
      component_fixture(
        name: "say_hello",
        body: "<p><%= @greeting %>!</p>",
        attrs: [%{name: "greeting", type: "atom"}]
      )

      components = Content.list_components(@site, per_page: :infinity, preloads: [:attrs])

      {:ok, mod} = ComponentModuleLoader.load_components(@site, components)
      assert render(mod.say_hello(%{greeting: :hello})) == "<p>hello!</p>"
    end

    test "load component with list attr" do
      component_fixture(
        name: "advice",
        body: """
        <p>Some good programming languages:</p>
        <ul>
          <li :for={lang <- @langs}><%= lang %></li>
        </ul>
        """,
        attrs: [%{name: "langs", type: "list"}]
      )

      components = Content.list_components(@site, per_page: :infinity, preloads: [:attrs])

      {:ok, mod} = ComponentModuleLoader.load_components(@site, components)

      assert render(mod.advice(%{langs: ["Erlang", "Elixir", "Rust"]})) ==
               "<p>Some good programming languages:</p>\n<ul>\n  <li>Erlang</li><li>Elixir</li><li>Rust</li>\n</ul>"
    end

    test "load component with map attr" do
      component_fixture(
        name: "user_info",
        body: """
        <h1>User info:</h1>
        <p :for={{key, value} <- @user}><%= key %>: <%= value %></p>
        """,
        attrs: [%{name: "user", type: "map"}]
      )

      components = Content.list_components(@site, per_page: :infinity, preloads: [:attrs])

      {:ok, mod} = ComponentModuleLoader.load_components(@site, components)

      assert render(mod.user_info(%{user: %{name: "Joe", age: 20}})) == "<h1>User info:</h1>\n<p>name: Joe</p><p>age: 20</p>"
    end

    test "load component with struct attrs" do
      component_fixture(
        name: "render_component_site",
        body: "<h1>Component site: <%= @component.site %></h1>",
        attrs: [%{name: "component", type: "Beacon.Content.Component"}]
      )

      components = Content.list_components(@site, per_page: :infinity, preloads: [:attrs])

      {:ok, mod} = ComponentModuleLoader.load_components(@site, components)
      assert render(mod.render_component_site(%{component: %Beacon.Content.Component{site: :dy}})) == "<h1>Component site: dy</h1>"
    end
  end

  describe "function component options" do
    test "load component with options: required and default" do
      component_fixture(
        name: "say_hello",
        body: "<h1>Hello <%= @first_name %> <%= @last_name %></h1>",
        attrs: [
          %{name: "first_name", type: "string", opts: [required: true]},
          %{name: "last_name", type: "string", opts: [default: "Doe"]}
        ]
      )

      components = Content.list_components(@site, per_page: :infinity, preloads: [:attrs])

      {:ok, mod} = ComponentModuleLoader.load_components(@site, components)
      assert render(mod.say_hello(%{first_name: "Jane"})) == "<h1>Hello Jane Doe</h1>"
      assert render(mod.say_hello(%{first_name: "Jane", last_name: "Foo Bar"})) == "<h1>Hello Jane Foo Bar</h1>"

      assert_raise KeyError, "key :first_name not found in: %{last_name: \"Doe\", __given__: %{}}", fn ->
        render(mod.say_hello(%{}))
      end
    end

    test "load component with options: values and doc" do
      component_fixture(
        name: "error_message",
        body: "<h1 class={@kind}>Failed Operation</h1>",
        attrs: [
          %{name: "kind", type: "atom", opts: [values: [:info, :error], doc: "test function component doc"]}
        ]
      )

      components = Content.list_components(@site, per_page: :infinity, preloads: [:attrs])

      {:ok, mod} = ComponentModuleLoader.load_components(@site, components)
      assert render(mod.error_message(%{kind: :info})) == "<h1 class=\"info\">Failed Operation</h1>"
      assert render(mod.error_message(%{kind: :error})) == "<h1 class=\"error\">Failed Operation</h1>"
    end
  end
end
