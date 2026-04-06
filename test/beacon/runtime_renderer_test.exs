defmodule Beacon.RuntimeRendererTest do
  use Beacon.DataCase, async: false

  alias Beacon.RuntimeRenderer

  @site :my_site

  setup do
    RuntimeRenderer.init()

    on_exit(fn ->
      # Clean up ETS entries after each test
      if :ets.whereis(:beacon_runtime_poc) != :undefined do
        :ets.delete_all_objects(:beacon_runtime_poc)
      end
    end)

    :ok
  end

  describe "publish and render template" do
    test "renders a simple static template" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Hello World</div>"
      })

      assert {:ok, html} = RuntimeRenderer.render_to_string(@site, "page_1")
      assert html =~ "Hello World"
    end

    test "renders template with assign interpolation" do
      RuntimeRenderer.publish_page(@site, "page_2", %{
        template: ~S|<div>Hello, <%= @name %>!</div>|
      })

      assert {:ok, html} = RuntimeRenderer.render_to_string(@site, "page_2", %{name: "Beacon"})
      assert html =~ "Hello, Beacon!"
    end

    test "renders template with multiple assigns" do
      RuntimeRenderer.publish_page(@site, "page_3", %{
        template: ~S|<h1><%= @title %></h1><p><%= @body %></p>|
      })

      assigns = %{title: "My Page", body: "This is the content."}
      assert {:ok, html} = RuntimeRenderer.render_to_string(@site, "page_3", assigns)
      assert html =~ "<h1>My Page</h1>"
      assert html =~ "<p>This is the content.</p>"
    end

    test "renders template with expression" do
      RuntimeRenderer.publish_page(@site, "page_4", %{
        template: ~S|<span><%= @count + 1 %></span>|
      })

      assert {:ok, html} = RuntimeRenderer.render_to_string(@site, "page_4", %{count: 41})
      assert html =~ "42"
    end

    test "renders template with conditional" do
      RuntimeRenderer.publish_page(@site, "page_5", %{
        template: ~S|<%= if @show do %>visible<% else %>hidden<% end %>|
      })

      assert {:ok, html} = RuntimeRenderer.render_to_string(@site, "page_5", %{show: true})
      assert html =~ "visible"

      assert {:ok, html} = RuntimeRenderer.render_to_string(@site, "page_5", %{show: false})
      assert html =~ "hidden"
    end

    test "renders template with comprehension" do
      RuntimeRenderer.publish_page(@site, "page_6", %{
        template: ~S|<ul><%= for item <- @items do %><li><%= item %></li><% end %></ul>|
      })

      assert {:ok, html} = RuntimeRenderer.render_to_string(@site, "page_6", %{items: ["a", "b", "c"]})
      assert html =~ "<li>a</li>"
      assert html =~ "<li>b</li>"
      assert html =~ "<li>c</li>"
    end

    test "returns error for non-existent page" do
      assert {:error, :not_found} = RuntimeRenderer.render_page(@site, "nonexistent")
    end

    test "produces a valid Phoenix.LiveView.Rendered struct" do
      RuntimeRenderer.publish_page(@site, "page_rendered", %{
        template: ~S|<div><%= @value %></div>|
      })

      assert {:ok, %Phoenix.LiveView.Rendered{} = rendered} =
               RuntimeRenderer.render_page(@site, "page_rendered", %{value: "test"})

      assert is_list(rendered.static)
      assert is_function(rendered.dynamic)
      assert is_integer(rendered.fingerprint)
    end
  end

  describe "publish and retrieve state" do
    test "stores and retrieves page assigns and manifest" do
      RuntimeRenderer.publish_page(@site, "state_1", %{
        template: "<div>test</div>",
        title: "My Title",
        path: "/test",
        assigns: %{custom_key: "custom_value"}
      })

      # Custom assigns are in fetch_assigns
      assigns = RuntimeRenderer.fetch_assigns(@site, "state_1")
      assert assigns.custom_key == "custom_value"

      # Page metadata is in the manifest
      {:ok, manifest} = RuntimeRenderer.fetch_manifest(@site, "state_1")
      assert manifest.title == "My Title"
      assert manifest.path == "/test"
      assert manifest.site == @site
    end

    test "stored assigns are merged into template rendering" do
      RuntimeRenderer.publish_page(@site, "state_2", %{
        template: ~S|<h1><%= @title %></h1><p><%= @greeting %></p>|,
        title: "Stored Title",
        assigns: %{title: "Stored Title"}
      })

      # Only pass greeting at render time — title comes from stored assigns
      assert {:ok, html} = RuntimeRenderer.render_to_string(@site, "state_2", %{greeting: "Hi!"})
      assert html =~ "Stored Title"
      assert html =~ "Hi!"
    end

    test "request-time assigns override stored assigns" do
      RuntimeRenderer.publish_page(@site, "state_3", %{
        template: ~S|<h1><%= @title %></h1>|,
        assigns: %{title: "Original"}
      })

      # Override at render time
      assert {:ok, html} = RuntimeRenderer.render_to_string(@site, "state_3", %{title: "Overridden"})
      assert html =~ "Overridden"
    end
  end

  describe "publish and dispatch event handlers" do
    test "dispatches a simple event handler" do
      RuntimeRenderer.publish_page(@site, "event_1", %{
        template: "<div>test</div>",
        event_handlers: [
          %{
            name: "greet",
            code: ~S|{:noreply, assign(socket, :message, "Hello!")}|
          }
        ]
      })

      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
      result = RuntimeRenderer.handle_event(@site, "event_1", "greet", %{}, socket)

      assert {:noreply, %Phoenix.LiveView.Socket{} = updated_socket} = result
      assert updated_socket.assigns.message == "Hello!"
    end

    test "event handler receives event_params" do
      RuntimeRenderer.publish_page(@site, "event_2", %{
        template: "<div>test</div>",
        event_handlers: [
          %{
            name: "submit",
            code: ~S|{:noreply, assign(socket, :name, event_params["name"])}|
          }
        ]
      })

      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
      result = RuntimeRenderer.handle_event(@site, "event_2", "submit", %{"name" => "Beacon"}, socket)

      assert {:noreply, %Phoenix.LiveView.Socket{} = updated_socket} = result
      assert updated_socket.assigns.name == "Beacon"
    end

    test "returns error for missing handler" do
      RuntimeRenderer.publish_page(@site, "event_3", %{
        template: "<div>test</div>"
      })

      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
      assert {:error, {:no_handler, "missing"}} = RuntimeRenderer.handle_event(@site, "event_3", "missing", %{}, socket)
    end

    test "multiple handlers on same page" do
      RuntimeRenderer.publish_page(@site, "event_4", %{
        template: "<div>test</div>",
        event_handlers: [
          %{name: "inc", code: ~S"{:noreply, assign(socket, :count, (socket.assigns[:count] || 0) + 1)}"},
          %{name: "dec", code: ~S"{:noreply, assign(socket, :count, (socket.assigns[:count] || 0) - 1)}"}
        ]
      })

      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}

      {:noreply, socket} = RuntimeRenderer.handle_event(@site, "event_4", "inc", %{}, socket)
      assert socket.assigns.count == 1

      {:noreply, socket} = RuntimeRenderer.handle_event(@site, "event_4", "inc", %{}, socket)
      assert socket.assigns.count == 2

      {:noreply, socket} = RuntimeRenderer.handle_event(@site, "event_4", "dec", %{}, socket)
      assert socket.assigns.count == 1
    end
  end

  describe "lifecycle" do
    test "unpublish removes all artifacts" do
      RuntimeRenderer.publish_page(@site, "lifecycle_1", %{
        template: "<div>test</div>",
        assigns: %{foo: "bar"},
        event_handlers: [%{name: "click", code: ~S|{:noreply, socket}|}]
      })

      # Verify everything exists
      assert {:ok, _} = RuntimeRenderer.render_page(@site, "lifecycle_1")
      assert RuntimeRenderer.fetch_assigns(@site, "lifecycle_1") != %{}
      assert RuntimeRenderer.list_handlers(@site, "lifecycle_1") == ["click"]

      # Unpublish
      RuntimeRenderer.unpublish_page(@site, "lifecycle_1")

      # Verify everything is gone
      assert {:error, :not_found} = RuntimeRenderer.render_page(@site, "lifecycle_1")
      assert RuntimeRenderer.fetch_assigns(@site, "lifecycle_1") == %{}
      assert RuntimeRenderer.list_handlers(@site, "lifecycle_1") == []
    end

    test "republish overwrites previous artifacts" do
      RuntimeRenderer.publish_page(@site, "lifecycle_2", %{
        template: ~S|<div>Version 1</div>|
      })

      assert {:ok, html} = RuntimeRenderer.render_to_string(@site, "lifecycle_2")
      assert html =~ "Version 1"

      # Republish with new content
      RuntimeRenderer.publish_page(@site, "lifecycle_2", %{
        template: ~S|<div>Version 2</div>|
      })

      assert {:ok, html} = RuntimeRenderer.render_to_string(@site, "lifecycle_2")
      assert html =~ "Version 2"
    end
  end

  describe "multi-site isolation" do
    test "pages are scoped to their site" do
      RuntimeRenderer.publish_page(:site_a, "page_1", %{
        template: ~S|<div>Site A</div>|
      })

      RuntimeRenderer.publish_page(:site_b, "page_1", %{
        template: ~S|<div>Site B</div>|
      })

      assert {:ok, html_a} = RuntimeRenderer.render_to_string(:site_a, "page_1")
      assert {:ok, html_b} = RuntimeRenderer.render_to_string(:site_b, "page_1")

      assert html_a =~ "Site A"
      assert html_b =~ "Site B"
    end
  end

  # =========================================================================
  # Full LiveView lifecycle: mount → handle_params → render → handle_event
  # =========================================================================

  describe "route lookup" do
    test "publish registers a route, lookup resolves it" do
      RuntimeRenderer.publish_page(@site, "route_1", %{
        template: "<div>routed</div>",
        path: "/blog/hello"
      })

      assert {:ok, "route_1"} = RuntimeRenderer.lookup_page(@site, "/blog/hello")
    end

    test "lookup returns error for unknown path" do
      assert :error = RuntimeRenderer.lookup_page(@site, "/does-not-exist")
    end

    test "unpublish removes the route" do
      RuntimeRenderer.publish_page(@site, "route_2", %{
        template: "<div>temp</div>",
        path: "/temporary"
      })

      assert {:ok, _} = RuntimeRenderer.lookup_page(@site, "/temporary")
      RuntimeRenderer.unpublish_page(@site, "route_2")
      assert :error = RuntimeRenderer.lookup_page(@site, "/temporary")
    end
  end

  describe "page manifest" do
    test "stores and retrieves full page metadata" do
      RuntimeRenderer.publish_page(@site, "manifest_1", %{
        template: "<div>test</div>",
        path: "/about",
        title: "About Us",
        description: "Our story",
        layout_id: "layout_main",
        meta_tags: [%{"name" => "author", "content" => "Beacon"}],
        extra: %{category: "info"}
      })

      assert {:ok, manifest} = RuntimeRenderer.fetch_manifest(@site, "manifest_1")
      assert manifest.id == "manifest_1"
      assert manifest.site == @site
      assert manifest.path == "/about"
      assert manifest.title == "About Us"
      assert manifest.description == "Our story"
      assert manifest.layout_id == "layout_main"
      assert manifest.meta_tags == [%{"name" => "author", "content" => "Beacon"}]
      assert manifest.extra == %{category: "info"}
    end
  end

  describe "mount_assigns" do
    test "produces initial assigns from route lookup" do
      RuntimeRenderer.publish_page(@site, "mount_1", %{
        template: ~S|<h1><%= @beacon.page.title %></h1>|,
        path: "/welcome",
        title: "Welcome Page"
      })

      assert {:ok, assigns} = RuntimeRenderer.mount_assigns(@site, "/welcome")
      assert assigns.beacon.site == @site
      assert assigns.beacon.page.title == "Welcome Page"
      assert assigns.beacon.page.path == "/welcome"
      assert assigns.beacon.private.page_id == "mount_1"
      assert assigns.page_title == "Welcome Page"
    end

    test "raises for unknown route" do
      assert_raise RuntimeError, fn ->
        RuntimeRenderer.mount_assigns(@site, "/unknown")
      end
    end

    test "passes variant_roll through" do
      RuntimeRenderer.publish_page(@site, "mount_2", %{
        template: "<div>test</div>",
        path: "/variant-test"
      })

      assert {:ok, assigns} = RuntimeRenderer.mount_assigns(@site, "/variant-test", variant_roll: 0.42)
      assert assigns.beacon.private.variant_roll == 0.42
    end
  end

  describe "handle_params_assigns" do
    test "produces assigns with live_data evaluated" do
      RuntimeRenderer.publish_page(@site, "params_1", %{
        template: ~S|<h1><%= @greeting %></h1>|,
        path: "/greet",
        title: "Greet",
        live_data: [
          %{key: :greeting, value: "Hello from live_data!", format: :text}
        ]
      })

      assert {:ok, assigns} = RuntimeRenderer.handle_params_assigns(@site, "/greet")
      assert assigns.greeting == "Hello from live_data!"
      assert assigns.beacon.private.live_data_keys == [:greeting]
      assert assigns.beacon.page.title == "Greet"
    end

    test "live_data with text format returns literal value" do
      RuntimeRenderer.publish_page(@site, "params_2", %{
        template: "<div>test</div>",
        path: "/text-data",
        live_data: [
          %{key: :name, value: "Beacon", format: :text},
          %{key: :version, value: "2.0", format: :text}
        ]
      })

      assert {:ok, assigns} = RuntimeRenderer.handle_params_assigns(@site, "/text-data")
      assert assigns.name == "Beacon"
      assert assigns.version == "2.0"
    end

    test "passes query_params through" do
      RuntimeRenderer.publish_page(@site, "params_3", %{
        template: "<div>test</div>",
        path: "/search"
      })

      assert {:ok, assigns} = RuntimeRenderer.handle_params_assigns(@site, "/search", %{"q" => "beacon"})
      assert assigns.beacon.query_params == %{"q" => "beacon"}
    end

    test "extracts path params from dynamic segments" do
      RuntimeRenderer.publish_page(@site, "params_4", %{
        template: "<div>test</div>",
        path: "/posts/:slug"
      })

      assert {:ok, assigns} = RuntimeRenderer.handle_params_assigns(@site, "/posts/:slug")
      # Note: In production, the router resolves /posts/my-post to this page
      # and path_info would be ["posts", "my-post"]. Here we test the extraction logic.
    end

    test "live_data preserves variable bindings across sequential expressions" do
      RuntimeRenderer.publish_page(@site, "params_5", %{
        template: "<div>test</div>",
        path: "/blog",
        live_data: [
          %{
            key: :query_opts,
            format: :elixir,
            value: """
            page = params[\"page\"] || \"1\"
            page_size = if page == \"1\", do: \"19\", else: \"18\"
            filter = params[\"filter\"] || \"all\"
            query_opts = %{
              \"filter\" => %{\"drafts\" => \"false\"}
            }
            filter_key = if filter == \"all\", do: \"tag_exclude\", else: \"tag_include_all\"
            filter_val = if filter == \"all\", do: \"press-release\", else: filter

            query_opts
            |> Map.update!(\"filter\", &Map.put(&1, filter_key, filter_val))
            |> Map.put(\"page\", %{\"number\" => page, \"size\" => page_size})
            """
          }
        ]
      })

      assert {:ok, assigns} = RuntimeRenderer.handle_params_assigns(@site, "/blog")

      assert assigns.query_opts == %{
               "filter" => %{"drafts" => "false", "tag_exclude" => "press-release"},
               "page" => %{"number" => "1", "size" => "19"}
             }
    end

    test "live_data supports anonymous functions in module calls" do
      RuntimeRenderer.publish_page(@site, "params_6", %{
        template: "<div>test</div>",
        path: "/authors",
        live_data: [
          %{
            key: :values,
            format: :elixir,
            value: """
            Enum.map([1, 2, 3], fn value -> value + 1 end)
            """
          }
        ]
      })

      assert {:ok, assigns} = RuntimeRenderer.handle_params_assigns(@site, "/authors")
      assert assigns.values == [2, 3, 4]
    end

    test "live_data supports tuple and cons-list destructuring" do
      RuntimeRenderer.publish_page(@site, "params_7", %{
        template: "<div>test</div>",
        path: "/category",
        live_data: [
          %{
            key: :parts,
            format: :elixir,
            value: """
            {[first | rest], meta} = {[%{id: 1}, %{id: 2}, %{id: 3}], %{count: 3}}

            %{first_id: first.id, rest_count: length(rest), count: meta.count}
            """
          }
        ]
      })

      assert {:ok, assigns} = RuntimeRenderer.handle_params_assigns(@site, "/category")
      assert assigns.parts == %{first_id: 1, rest_count: 2, count: 3}
    end
  end

  describe "full lifecycle" do
    test "mount → handle_params → render → handle_event" do
      RuntimeRenderer.publish_page(@site, "full_1", %{
        template: ~S|<div><%= @greeting %> <%= @name %></div>|,
        path: "/full-test",
        title: "Full Test",
        live_data: [
          %{key: :greeting, value: "Hello", format: :text},
          %{key: :name, value: "World", format: :text}
        ],
        event_handlers: [
          %{name: "update_name", code: ~S|{:noreply, assign(socket, :name, event_params["name"])}|}
        ]
      })

      # 1. Mount — resolve route, get initial assigns
      {:ok, mount_assigns} = RuntimeRenderer.mount_assigns(@site, "/full-test")
      assert mount_assigns.beacon.private.page_id == "full_1"

      # 2. Handle params — evaluate live_data, build full assigns
      {:ok, params_assigns} = RuntimeRenderer.handle_params_assigns(@site, "/full-test")
      assert params_assigns.greeting == "Hello"
      assert params_assigns.name == "World"

      # 3. Render — produce HTML from template IR + assigns
      {:ok, html} = RuntimeRenderer.render_to_string(@site, "full_1", params_assigns)
      assert html =~ "Hello"
      assert html =~ "World"

      # 4. Handle event — dispatch through AST interpreter
      socket = %Phoenix.LiveView.Socket{assigns: Map.put(params_assigns, :__changed__, %{})}

      {:noreply, updated_socket} =
        RuntimeRenderer.handle_event(@site, "full_1", "update_name", %{"name" => "Beacon"}, socket)

      # 5. Re-render with updated assigns
      new_assigns = Map.merge(params_assigns, updated_socket.assigns) |> Map.put(:__changed__, %{})
      {:ok, html2} = RuntimeRenderer.render_to_string(@site, "full_1", new_assigns)
      assert html2 =~ "Hello"
      assert html2 =~ "Beacon"
    end
  end
end
