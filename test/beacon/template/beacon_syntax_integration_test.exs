defmodule Beacon.Template.BeaconSyntaxIntegrationTest do
  use ExUnit.Case, async: false

  alias Beacon.RuntimeRenderer

  @site :my_site

  setup do
    RuntimeRenderer.init()

    on_exit(fn ->
      if :ets.whereis(:beacon_runtime_poc) != :undefined do
        :ets.delete_all_objects(:beacon_runtime_poc)
      end
    end)

    :ok
  end

  describe "beacon syntax publish and render" do
    test "simple template with static content" do
      RuntimeRenderer.publish_page(@site, "beacon_1", %{
        template: "<h1>Hello World</h1>",
        path: "/beacon-test",
        format: :beacon
      })

      {:ok, rendered} = RuntimeRenderer.render_to_string(@site, "beacon_1")
      assert rendered =~ "Hello World"
      assert rendered =~ "<h1>"
    end

    test "template with expression binding" do
      RuntimeRenderer.publish_page(@site, "beacon_2", %{
        template: "<p>{{ greeting }}</p>",
        path: "/beacon-expr",
        format: :beacon
      })

      {:ok, rendered} = RuntimeRenderer.render_to_string(@site, "beacon_2", %{"greeting" => "Hi there"})
      assert rendered =~ "Hi there"
    end

    test "template with conditional" do
      RuntimeRenderer.publish_page(@site, "beacon_3", %{
        template: ~s(<div :if="show">Visible</div><div :else>Hidden</div>),
        path: "/beacon-cond",
        format: :beacon
      })

      {:ok, shown} = RuntimeRenderer.render_to_string(@site, "beacon_3", %{"show" => true})
      assert shown =~ "Visible"
      refute shown =~ "Hidden"

      {:ok, hidden} = RuntimeRenderer.render_to_string(@site, "beacon_3", %{"show" => false})
      assert hidden =~ "Hidden"
      refute hidden =~ "Visible"
    end

    test "template with loop" do
      RuntimeRenderer.publish_page(@site, "beacon_4", %{
        template: ~s(<ul><li :for="item in items">{{ item.name }}</li></ul>),
        path: "/beacon-loop",
        format: :beacon
      })

      assigns = %{"items" => [%{"name" => "A"}, %{"name" => "B"}, %{"name" => "C"}]}
      {:ok, rendered} = RuntimeRenderer.render_to_string(@site, "beacon_4", assigns)

      assert rendered =~ "A"
      assert rendered =~ "B"
      assert rendered =~ "C"
    end

    test "template with filter" do
      RuntimeRenderer.publish_page(@site, "beacon_5", %{
        template: ~s(<p>{{ title | upcase }}</p>),
        path: "/beacon-filter",
        format: :beacon
      })

      {:ok, rendered} = RuntimeRenderer.render_to_string(@site, "beacon_5", %{"title" => "hello"})
      assert rendered =~ "HELLO"
    end

    test "template with dynamic attribute" do
      RuntimeRenderer.publish_page(@site, "beacon_6", %{
        template: ~s(<a :href="post.url">Click</a>),
        path: "/beacon-attr",
        format: :beacon
      })

      {:ok, rendered} = RuntimeRenderer.render_to_string(@site, "beacon_6", %{"post" => %{"url" => "/blog/hello"}})
      assert rendered =~ ~s(href="/blog/hello")
    end

    test "template with event binding" do
      RuntimeRenderer.publish_page(@site, "beacon_7", %{
        template: ~s(<button @click="submit_form">Go</button>),
        path: "/beacon-event",
        format: :beacon
      })

      {:ok, rendered} = RuntimeRenderer.render_to_string(@site, "beacon_7")
      assert rendered =~ ~s(phx-click="submit_form")
    end

    test "heex format still works (backward compatible)" do
      RuntimeRenderer.publish_page(@site, "heex_1", %{
        template: ~S(<h1><%= assigns[:name] || "World" %></h1>),
        path: "/heex-test",
        format: :heex
      })

      {:ok, rendered} = RuntimeRenderer.render_to_string(@site, "heex_1", %{name: "Brian"})
      assert rendered =~ "Brian"
    end

    test "complex blog-like template" do
      RuntimeRenderer.publish_page(@site, "beacon_blog", %{
        template: """
        <main>
          <h1 :if="filter == 'all'">Blog</h1>
          <h1 :else>{{ pretty_filter }}</h1>
          <div :for="post in posts">
            <h3>{{ post.title }}</h3>
            <p>{{ post.date | format_date: "%B %Y" }}</p>
            <a :href="post.post_path">Read more</a>
          </div>
        </main>
        """,
        path: "/beacon-blog",
        format: :beacon
      })

      assigns = %{
        "filter" => "all",
        "pretty_filter" => "Elixir",
        "posts" => [
          %{"title" => "Post 1", "date" => "2023-12-05T00:00:00Z", "post_path" => "/blog/post-1"},
          %{"title" => "Post 2", "date" => "2024-01-15T00:00:00Z", "post_path" => "/blog/post-2"}
        ]
      }

      {:ok, rendered} = RuntimeRenderer.render_to_string(@site, "beacon_blog", assigns)

      assert rendered =~ "Blog"
      refute rendered =~ "Elixir"
      assert rendered =~ "Post 1"
      assert rendered =~ "Post 2"
      assert rendered =~ "December 2023"
      assert rendered =~ "January 2024"
      assert rendered =~ ~s(href="/blog/post-1")
    end
  end
end
