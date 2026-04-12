defmodule Beacon.Template.ParserTest do
  use ExUnit.Case, async: true

  alias Beacon.Template.Parser

  describe "text and interpolation" do
    test "static text" do
      assert [%{type: :text, value: "Hello world"}] = Parser.parse("Hello world")
    end

    test "simple interpolation" do
      assert [%{type: :expression, path: "post.title", filters: []}] =
               Parser.parse("{{ post.title }}")
    end

    test "interpolation with surrounding text" do
      result = Parser.parse("Hello {{ name }}!")

      assert [
               %{type: :text, value: "Hello "},
               %{type: :expression, path: "name", filters: []},
               %{type: :text, value: "!"}
             ] = result
    end

    test "interpolation with filter" do
      [%{type: :expression, path: "post.title", filters: filters}] =
        Parser.parse("{{ post.title | truncate: 200 }}")

      assert [%{name: "truncate", args: [200]}] = filters
    end

    test "interpolation with chained filters" do
      [%{type: :expression, path: "name", filters: filters}] =
        Parser.parse("{{ name | upcase | truncate: 50 }}")

      assert [%{name: "upcase", args: []}, %{name: "truncate", args: [50]}] = filters
    end
  end

  describe "elements" do
    test "simple element" do
      [el] = Parser.parse("<div>Hello</div>")

      assert el.type == :element
      assert el.tag == "div"
      assert [%{type: :text, value: "Hello"}] = el.children
    end

    test "element with static attributes" do
      [el] = Parser.parse(~s(<div class="card" id="main">text</div>))

      assert el.attrs["class"] == "card"
      assert el.attrs["id"] == "main"
    end

    test "element with dynamic prop" do
      [el] = Parser.parse(~s(<a :href="post.url">Link</a>))

      assert %{type: :expression, path: "post.url"} = el.attrs["href"]
    end

    test "element with event" do
      [el] = Parser.parse(~s(<button @click="submit_form">Go</button>))

      assert el.events == %{"click" => "submit_form"}
    end

    test "nested elements" do
      [outer] = Parser.parse("<div><span>Inner</span></div>")

      assert outer.tag == "div"
      [inner] = outer.children
      assert inner.tag == "span"
      assert [%{type: :text, value: "Inner"}] = inner.children
    end

    test "self-closing element" do
      [el] = Parser.parse(~s(<img src="photo.jpg"/>))
      assert el.tag == "img"
      assert el.attrs["src"] == "photo.jpg"
    end
  end

  describe "conditionals" do
    test "simple :if" do
      [cond_node] = Parser.parse(~s(<div :if="post.featured">Featured</div>))

      assert cond_node.type == :conditional
      assert cond_node.test == %{path: "post.featured", op: nil, value: nil}
      assert [%{type: :element, tag: "div"}] = cond_node.then
      assert cond_node.else == []
    end

    test ":if with comparison" do
      [cond_node] = Parser.parse(~s(<span :if="status == 'published'">Live</span>))

      assert cond_node.test.path == "status"
      assert cond_node.test.op == "=="
      assert cond_node.test.value == "published"
    end

    test ":if/:else" do
      result = Parser.parse("""
      <div :if="show">Yes</div>
      <div :else>No</div>
      """)

      assert [cond_node] = result
      assert cond_node.type == :conditional
      assert [%{type: :element, children: [%{type: :text, value: "Yes"}]}] = cond_node.then
      assert [%{type: :element, children: [%{type: :text, value: "No"}]}] = cond_node.else
    end

    test ":if/:else-if/:else" do
      result = Parser.parse("""
      <span :if="status == 'published'">Live</span>
      <span :else-if="status == 'draft'">Draft</span>
      <span :else>Unknown</span>
      """)

      assert [cond_node] = result
      assert cond_node.type == :conditional
      assert cond_node.test.op == "=="
      assert cond_node.test.value == "published"

      # else branch contains another conditional
      [else_cond] = cond_node.else
      assert else_cond.type == :conditional
      assert else_cond.test.value == "draft"
      assert [%{type: :element, children: [%{type: :text, value: "Unknown"}]}] = else_cond.else
    end

    test ":if with boolean operators" do
      [cond_node] = Parser.parse(~s(<div :if="featured and published">Both</div>))

      assert cond_node.test.op == "and"
      assert cond_node.test.left.path == "featured"
      assert cond_node.test.right.path == "published"
    end
  end

  describe "loops" do
    test "simple :for" do
      [loop_node] = Parser.parse("""
      <div :for="post in posts"><span>{{ post.title }}</span></div>
      """)

      assert loop_node.type == :loop
      assert loop_node.iterator == "post"
      assert loop_node.iterable == "posts"
      assert [%{type: :element, tag: "div"}] = loop_node.children
    end

    test ":for with nested interpolation" do
      [loop_node] = Parser.parse("""
      <li :for="item in items">{{ item.name }}</li>
      """)

      assert loop_node.iterator == "item"
      [el] = loop_node.children
      assert [%{type: :expression, path: "item.name"}] = el.children
    end
  end

  describe "fragments" do
    test "template element as fragment" do
      result = Parser.parse("""
      <template :if="show">
        <h1>Title</h1>
        <p>Body</p>
      </template>
      """)

      assert [cond_node] = result
      assert cond_node.type == :conditional
      [frag] = cond_node.then
      assert frag.type == :fragment
      assert length(frag.children) == 2
    end

    test "template :for as fragment" do
      [loop_node] = Parser.parse("""
      <template :for="item in items">
        <dt>{{ item.term }}</dt>
        <dd>{{ item.def }}</dd>
      </template>
      """)

      assert loop_node.type == :loop
      [frag] = loop_node.children
      assert frag.type == :fragment
    end
  end

  describe "components" do
    test "component with props" do
      [el] = Parser.parse(~s(<post-card :title="post.title" :image="post.image"/>))

      assert el.type == :element
      assert el.tag == "post-card"
      assert %{type: :expression, path: "post.title"} = el.attrs["title"]
      assert %{type: :expression, path: "post.image"} = el.attrs["image"]
    end

    test "component with event" do
      [el] = Parser.parse(~s(<button-cta @click="submit">Go</button-cta>))

      assert el.events == %{"click" => "submit"}
    end
  end

  describe "complex templates" do
    test "blog listing pattern" do
      result = Parser.parse("""
      <main>
        <h1 :if="filter == 'all'">Blog</h1>
        <h1 :else>{{ pretty_filter }}</h1>
        <div :for="post in past_posts">
          <h3>{{ post.title }}</h3>
          <p>{{ post.published_at | format_date: "%B %d, %Y" }}</p>
        </div>
      </main>
      """)

      assert [main] = result
      assert main.tag == "main"
      # First child should be a conditional (the h1 if/else)
      [cond_node | rest] = main.children |> Enum.reject(&match?(%{type: :text, value: "\n"}, &1))
      assert cond_node.type == :conditional
    end
  end
end
