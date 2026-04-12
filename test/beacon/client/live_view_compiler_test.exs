defmodule Beacon.Client.LiveViewCompilerTest do
  use ExUnit.Case, async: true

  alias Beacon.Client.LiveViewCompiler
  alias Beacon.Template.Parser

  describe "render_to_string/2" do
    test "static text" do
      ast = Parser.parse("Hello world")
      assert LiveViewCompiler.render_to_string(ast, %{}) == "Hello world"
    end

    test "expression binding" do
      ast = Parser.parse("Hello {{ name }}!")
      assert LiveViewCompiler.render_to_string(ast, %{"name" => "Brian"}) == "Hello Brian!"
    end

    test "nested path resolution" do
      ast = Parser.parse("{{ post.title }}")
      assigns = %{"post" => %{"title" => "My Post"}}
      assert LiveViewCompiler.render_to_string(ast, assigns) == "My Post"
    end

    test "deeply nested path" do
      ast = Parser.parse("{{ post.author.name }}")
      assigns = %{"post" => %{"author" => %{"name" => "Alice"}}}
      assert LiveViewCompiler.render_to_string(ast, assigns) == "Alice"
    end

    test "missing path resolves to empty string" do
      ast = Parser.parse("{{ missing.path }}")
      assert LiveViewCompiler.render_to_string(ast, %{}) == ""
    end

    test "HTML element" do
      ast = Parser.parse(~s(<div class="card">Content</div>))
      result = LiveViewCompiler.render_to_string(ast, %{})
      assert result =~ "<div"
      assert result =~ ~s(class="card")
      assert result =~ "Content"
      assert result =~ "</div>"
    end

    test "self-closing element" do
      ast = Parser.parse(~s(<img src="photo.jpg"/>))
      result = LiveViewCompiler.render_to_string(ast, %{})
      assert result =~ "<img"
      assert result =~ ~s(src="photo.jpg")
      assert result =~ "/>"
      refute result =~ "</img>"
    end

    test "dynamic attribute" do
      ast = Parser.parse(~s(<a :href="post.url">Link</a>))
      assigns = %{"post" => %{"url" => "/blog/hello"}}
      result = LiveViewCompiler.render_to_string(ast, assigns)
      assert result =~ ~s(href="/blog/hello")
    end

    test "event binding becomes phx attribute" do
      ast = Parser.parse(~s(<button @click="submit_form">Go</button>))
      result = LiveViewCompiler.render_to_string(ast, %{})
      assert result =~ ~s(phx-click="submit_form")
    end

    test "HTML escaping in text" do
      ast = Parser.parse("{{ content }}")
      assigns = %{"content" => "<script>alert('xss')</script>"}
      result = LiveViewCompiler.render_to_string(ast, assigns)
      refute result =~ "<script>"
      assert result =~ "&lt;script&gt;"
    end
  end

  describe "conditionals" do
    test "truthy path renders then branch" do
      ast = Parser.parse(~s(<div :if="show">Visible</div>))
      result = LiveViewCompiler.render_to_string(ast, %{"show" => true})
      assert result =~ "Visible"
    end

    test "falsy path renders else branch" do
      ast = Parser.parse("""
      <div :if="show">Yes</div>
      <div :else>No</div>
      """)

      result = LiveViewCompiler.render_to_string(ast, %{"show" => false})
      refute result =~ "Yes"
      assert result =~ "No"
    end

    test "comparison operator" do
      ast = Parser.parse(~s(<span :if="status == 'active'">Active</span>))

      assert LiveViewCompiler.render_to_string(ast, %{"status" => "active"}) =~ "Active"
      refute LiveViewCompiler.render_to_string(ast, %{"status" => "inactive"}) =~ "Active"
    end

    test "nil is falsy" do
      ast = Parser.parse(~s(<div :if="value">Has value</div>))
      refute LiveViewCompiler.render_to_string(ast, %{"value" => nil}) =~ "Has value"
    end

    test "empty string is falsy" do
      ast = Parser.parse(~s(<div :if="value">Has value</div>))
      refute LiveViewCompiler.render_to_string(ast, %{"value" => ""}) =~ "Has value"
    end

    test "empty list is falsy" do
      ast = Parser.parse(~s(<div :if="items">Has items</div>))
      refute LiveViewCompiler.render_to_string(ast, %{"items" => []}) =~ "Has items"
    end
  end

  describe "loops" do
    test "iterates over list" do
      ast = Parser.parse("""
      <li :for="item in items">{{ item.name }}</li>
      """)

      assigns = %{"items" => [%{"name" => "A"}, %{"name" => "B"}, %{"name" => "C"}]}
      result = LiveViewCompiler.render_to_string(ast, assigns)

      assert result =~ "A"
      assert result =~ "B"
      assert result =~ "C"
    end

    test "empty collection renders nothing" do
      ast = Parser.parse(~s(<li :for="item in items">{{ item.name }}</li>))
      result = LiveViewCompiler.render_to_string(ast, %{"items" => []})
      refute result =~ "<li>"
    end

    test "nil collection renders nothing" do
      ast = Parser.parse(~s(<li :for="item in items">{{ item.name }}</li>))
      result = LiveViewCompiler.render_to_string(ast, %{})
      refute result =~ "<li>"
    end

    test "nested loop" do
      ast = Parser.parse("""
      <div :for="group in groups">
        <span :for="item in group.items">{{ item }}</span>
      </div>
      """)

      assigns = %{"groups" => [
        %{"items" => ["a", "b"]},
        %{"items" => ["c"]}
      ]}
      result = LiveViewCompiler.render_to_string(ast, assigns)

      assert result =~ "a"
      assert result =~ "b"
      assert result =~ "c"
    end
  end

  describe "filters" do
    test "truncate" do
      ast = Parser.parse("{{ text | truncate: 5 }}")
      result = LiveViewCompiler.render_to_string(ast, %{"text" => "Hello World"})
      assert result == "Hello..."
    end

    test "upcase" do
      ast = Parser.parse("{{ name | upcase }}")
      result = LiveViewCompiler.render_to_string(ast, %{"name" => "hello"})
      assert result == "HELLO"
    end

    test "default with nil" do
      ast = Parser.parse("{{ value | default: \"N/A\" }}")
      result = LiveViewCompiler.render_to_string(ast, %{"value" => nil})
      assert result == "N/A"
    end

    test "chained filters" do
      ast = Parser.parse("{{ name | downcase | truncate: 3 }}")
      result = LiveViewCompiler.render_to_string(ast, %{"name" => "HELLO"})
      assert result == "hel..."
    end

    test "format_date with ISO string" do
      ast = Parser.parse("{{ date | format_date: \"%B %d, %Y\" }}")
      result = LiveViewCompiler.render_to_string(ast, %{"date" => "2023-12-05T17:16:49Z"})
      assert result == "December 05, 2023"
    end

    test "size filter on list" do
      ast = Parser.parse("{{ items | size }}")
      result = LiveViewCompiler.render_to_string(ast, %{"items" => [1, 2, 3]})
      assert result == "3"
    end

    test "join filter" do
      ast = Parser.parse("{{ tags | join: \", \" }}")
      result = LiveViewCompiler.render_to_string(ast, %{"tags" => ["elixir", "phoenix", "beacon"]})
      assert result == "elixir, phoenix, beacon"
    end
  end

  describe "fragments" do
    test "renders children without wrapper" do
      ast = Parser.parse("""
      <template :if="show">
        <h1>Title</h1>
        <p>Body</p>
      </template>
      """)

      result = LiveViewCompiler.render_to_string(ast, %{"show" => true})
      assert result =~ "<h1>"
      assert result =~ "<p>"
      refute result =~ "<template>"
    end
  end

  describe "complex templates" do
    test "blog listing pattern" do
      ast = Parser.parse("""
      <main>
        <h1 :if="filter == 'all'">Blog</h1>
        <h1 :else>{{ pretty_filter }}</h1>
        <div :for="post in past_posts">
          <h3>{{ post.title }}</h3>
          <p>{{ post.date | format_date: "%B %Y" }}</p>
        </div>
      </main>
      """)

      assigns = %{
        "filter" => "all",
        "pretty_filter" => "Elixir",
        "past_posts" => [
          %{"title" => "Post 1", "date" => "2023-12-05T00:00:00Z"},
          %{"title" => "Post 2", "date" => "2024-01-15T00:00:00Z"}
        ]
      }

      result = LiveViewCompiler.render_to_string(ast, assigns)

      assert result =~ "Blog"
      refute result =~ "Elixir"
      assert result =~ "Post 1"
      assert result =~ "Post 2"
      assert result =~ "December 2023"
      assert result =~ "January 2024"
    end
  end
end
