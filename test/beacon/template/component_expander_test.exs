defmodule Beacon.Template.ComponentExpanderTest do
  use ExUnit.Case, async: true

  alias Beacon.Template.ComponentExpander
  alias Beacon.Template.Parser

  describe "expand/2" do
    test "simple component with static content" do
      page_ast = Parser.parse(~s(<post-card/>))

      registry = %{
        "post-card" => Parser.parse("<div class=\"card\">Card content</div>")
      }

      result = ComponentExpander.expand(page_ast, registry)

      assert [%{type: :element, tag: "div", attrs: %{"class" => "card"}}] = result
    end

    test "component with prop binding" do
      page_ast = Parser.parse(~s(<post-card :title="post.title"/>))

      registry = %{
        "post-card" => Parser.parse("<h2>{{ title }}</h2>")
      }

      result = ComponentExpander.expand(page_ast, registry)

      assert [%{type: :element, tag: "h2", children: children}] = result
      assert [%{type: :expression, path: "post.title"}] = children
    end

    test "component with nested path rewriting" do
      page_ast = Parser.parse(~s(<author-badge :author="post.author"/>))

      registry = %{
        "author-badge" => Parser.parse("<span>{{ author.name }}</span>")
      }

      result = ComponentExpander.expand(page_ast, registry)

      [span] = result
      assert [%{type: :expression, path: "post.author.name"}] = span.children
    end

    test "component with multiple props" do
      page_ast = Parser.parse(~s(<card :title="post.title" :image="post.image"/>))

      registry = %{
        "card" => Parser.parse("""
        <div>
          <h3>{{ title }}</h3>
          <img :src="image"/>
        </div>
        """)
      }

      result = ComponentExpander.expand(page_ast, registry)

      [div] = result
      children = Enum.reject(div.children, &match?(%{type: :text}, &1))
      [h3, img] = children

      assert [%{type: :expression, path: "post.title"}] = h3.children
      assert %{type: :expression, path: "post.image"} = img.attrs["src"]
    end

    test "component with static prop" do
      page_ast = Parser.parse(~s(<badge label="Featured"/>))

      registry = %{
        "badge" => Parser.parse("<span class=\"badge\">{{ label }}</span>")
      }

      result = ComponentExpander.expand(page_ast, registry)

      [span] = result
      assert [%{type: :text, value: "Featured"}] = span.children
    end

    test "component with conditional inside" do
      page_ast = Parser.parse(~s(<status-badge :active="item.active"/>))

      registry = %{
        "status-badge" => Parser.parse("""
        <span :if="active" class="green">Active</span>
        <span :else class="red">Inactive</span>
        """)
      }

      result = ComponentExpander.expand(page_ast, registry)

      assert [%{type: :conditional, test: %{path: "item.active"}}] = result
    end

    test "component with loop inside" do
      page_ast = Parser.parse(~s(<tag-list :tags="post.tags"/>))

      registry = %{
        "tag-list" => Parser.parse("""
        <ul><li :for="tag in tags">{{ tag.name }}</li></ul>
        """)
      }

      result = ComponentExpander.expand(page_ast, registry)

      [ul] = result
      children = Enum.reject(ul.children, &match?(%{type: :text}, &1))
      [loop] = children
      assert loop.type == :loop
      assert loop.iterable == "post.tags"
      assert loop.iterator == "tag"
    end

    test "nested components" do
      page_ast = Parser.parse(~s(<outer :data="page.data"/>))

      registry = %{
        "outer" => Parser.parse("<div><inner :value=\"data.value\"/></div>"),
        "inner" => Parser.parse("<span>{{ value }}</span>")
      }

      result = ComponentExpander.expand(page_ast, registry)

      [div] = result
      children = Enum.reject(div.children, &match?(%{type: :text}, &1))
      [span] = children
      assert [%{type: :expression, path: "page.data.value"}] = span.children
    end

    test "non-component elements pass through" do
      page_ast = Parser.parse("<div><p>Hello</p></div>")

      result = ComponentExpander.expand(page_ast, %{})

      assert [%{type: :element, tag: "div"}] = result
    end

    test "component inside loop preserves iterator scope" do
      page_ast = Parser.parse("""
      <div :for="post in posts">
        <post-title :title="post.title"/>
      </div>
      """)

      registry = %{
        "post-title" => Parser.parse("<h3>{{ title }}</h3>")
      }

      result = ComponentExpander.expand(page_ast, registry)

      [loop] = result
      assert loop.type == :loop
      [div] = loop.children
      children = Enum.reject(div.children, &match?(%{type: :text}, &1))
      [h3] = children
      assert [%{type: :expression, path: "post.title"}] = h3.children
    end

    test "raises on circular component references" do
      page_ast = Parser.parse(~s(<comp-a/>))

      registry = %{
        "comp-a" => Parser.parse(~s(<comp-b/>)),
        "comp-b" => Parser.parse(~s(<comp-a/>))
      }

      assert_raise Beacon.Template.ParseError, ~r/maximum depth/, fn ->
        ComponentExpander.expand(page_ast, registry)
      end
    end
  end
end
