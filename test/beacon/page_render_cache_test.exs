defmodule Beacon.PageRenderCacheTest do
  use Beacon.DataCase, async: false

  alias Beacon.PageRenderCache
  alias Beacon.RuntimeRenderer

  @site :my_site
  @table :beacon_runtime_poc

  setup do
    RuntimeRenderer.init()

    on_exit(fn ->
      if :ets.whereis(@table) != :undefined do
        :ets.delete_all_objects(@table)
      end
    end)

    :ok
  end

  describe "register_page_deps/3" do
    test "stores page dependencies and creates reverse mappings" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Hello</div>",
        path: "/hello",
        layout_id: "layout_1"
      })

      deps = %{
        layout_id: "layout_1",
        components: MapSet.new([:header, :footer]),
        data_sources: MapSet.new([:posts])
      }

      :ok = PageRenderCache.register_page_deps(@site, "page_1", deps)

      # Verify layout reverse mapping
      [{_, layout_pages}] = :ets.lookup(@table, {@site, :dep, :layout, "layout_1"})
      assert MapSet.member?(layout_pages, "page_1")

      # Verify component reverse mappings
      [{_, header_pages}] = :ets.lookup(@table, {@site, :dep, :component, :header})
      assert MapSet.member?(header_pages, "page_1")

      [{_, footer_pages}] = :ets.lookup(@table, {@site, :dep, :component, :footer})
      assert MapSet.member?(footer_pages, "page_1")

      # Verify data source reverse mapping
      [{_, posts_pages}] = :ets.lookup(@table, {@site, :dep, :data_source, :posts})
      assert MapSet.member?(posts_pages, "page_1")

      # Verify page deps stored
      [{_, stored_deps}] = :ets.lookup(@table, {@site, :dep, :page_deps, "page_1"})
      assert stored_deps.layout_id == "layout_1"
      assert MapSet.member?(stored_deps.components, :header)
      assert MapSet.member?(stored_deps.data_sources, :posts)
    end

    test "removes old dependencies when re-registering" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Hello</div>",
        path: "/hello",
        layout_id: "layout_1"
      })

      # Register initial deps
      deps1 = %{
        layout_id: "layout_1",
        components: MapSet.new([:header]),
        data_sources: MapSet.new([:posts])
      }
      :ok = PageRenderCache.register_page_deps(@site, "page_1", deps1)

      # Re-register with different deps
      deps2 = %{
        layout_id: "layout_2",
        components: MapSet.new([:sidebar]),
        data_sources: MapSet.new([:comments])
      }
      :ok = PageRenderCache.register_page_deps(@site, "page_1", deps2)

      # Old layout mapping should be removed
      assert :ets.lookup(@table, {@site, :dep, :layout, "layout_1"}) == []

      # Old component mapping should be removed
      assert :ets.lookup(@table, {@site, :dep, :component, :header}) == []

      # Old data source mapping should be removed
      assert :ets.lookup(@table, {@site, :dep, :data_source, :posts}) == []

      # New mappings should exist
      [{_, layout_pages}] = :ets.lookup(@table, {@site, :dep, :layout, "layout_2"})
      assert MapSet.member?(layout_pages, "page_1")

      [{_, sidebar_pages}] = :ets.lookup(@table, {@site, :dep, :component, :sidebar})
      assert MapSet.member?(sidebar_pages, "page_1")

      [{_, comments_pages}] = :ets.lookup(@table, {@site, :dep, :data_source, :comments})
      assert MapSet.member?(comments_pages, "page_1")
    end

    test "multiple pages can share the same layout" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Page 1</div>",
        path: "/page-1",
        layout_id: "layout_1"
      })

      RuntimeRenderer.publish_page(@site, "page_2", %{
        template: "<div>Page 2</div>",
        path: "/page-2",
        layout_id: "layout_1"
      })

      deps1 = %{layout_id: "layout_1", components: MapSet.new(), data_sources: MapSet.new()}
      deps2 = %{layout_id: "layout_1", components: MapSet.new(), data_sources: MapSet.new()}

      :ok = PageRenderCache.register_page_deps(@site, "page_1", deps1)
      :ok = PageRenderCache.register_page_deps(@site, "page_2", deps2)

      [{_, layout_pages}] = :ets.lookup(@table, {@site, :dep, :layout, "layout_1"})
      assert MapSet.member?(layout_pages, "page_1")
      assert MapSet.member?(layout_pages, "page_2")
    end

    test "removing one page from shared layout doesn't affect others" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Page 1</div>",
        path: "/page-1",
        layout_id: "layout_1"
      })

      RuntimeRenderer.publish_page(@site, "page_2", %{
        template: "<div>Page 2</div>",
        path: "/page-2",
        layout_id: "layout_1"
      })

      deps = %{layout_id: "layout_1", components: MapSet.new(), data_sources: MapSet.new()}
      :ok = PageRenderCache.register_page_deps(@site, "page_1", deps)
      :ok = PageRenderCache.register_page_deps(@site, "page_2", deps)

      # Re-register page_1 with a different layout
      new_deps = %{layout_id: "layout_2", components: MapSet.new(), data_sources: MapSet.new()}
      :ok = PageRenderCache.register_page_deps(@site, "page_1", new_deps)

      # layout_1 should still have page_2
      [{_, layout_pages}] = :ets.lookup(@table, {@site, :dep, :layout, "layout_1"})
      refute MapSet.member?(layout_pages, "page_1")
      assert MapSet.member?(layout_pages, "page_2")
    end
  end

  describe "extract_component_names/1" do
    test "extracts CMS component names from IR" do
      ir = %{
        static: ["<div>", "</div>"],
        fingerprint: 12345,
        dynamics: [
          %{deps: [], expr: {:component_call, {:component_fun, nil, :header}, {:component_assigns, []}}},
          %{deps: [], expr: {:component_call, {:component_fun, nil, :footer}, {:component_assigns, []}}},
          %{deps: [], expr: {:component_call, {:component_fun, Phoenix.Component, :link}, {:component_assigns, []}}}
        ]
      }

      names = PageRenderCache.extract_component_names(ir)
      assert MapSet.member?(names, :header)
      assert MapSet.member?(names, :footer)
      # Phoenix.Component functions should NOT be included
      refute MapSet.member?(names, :link)
    end

    test "extracts components from nested rendered blocks" do
      inner_ir = %{
        static: ["<span>", "</span>"],
        fingerprint: 67890,
        dynamics: [
          %{deps: [], expr: {:component_call, {:component_fun, nil, :sidebar}, {:component_assigns, []}}}
        ]
      }

      ir = %{
        static: ["<div>", "</div>"],
        fingerprint: 12345,
        dynamics: [
          %{deps: [], expr: {:if, {:assign, :show}, {:nested_rendered, inner_ir}, {:literal, nil}}}
        ]
      }

      names = PageRenderCache.extract_component_names(ir)
      assert MapSet.member?(names, :sidebar)
    end

    test "extracts components from for expressions" do
      ir = %{
        static: ["<ul>", "</ul>"],
        fingerprint: 12345,
        dynamics: [
          %{deps: [], expr: {:for_expr, :item, {:assign, :items},
            {:component_call, {:component_fun, nil, :card}, {:component_assigns, []}}}}
        ]
      }

      names = PageRenderCache.extract_component_names(ir)
      assert MapSet.member?(names, :card)
    end

    test "extracts components from inner blocks" do
      inner_ir = %{
        static: ["<p>", "</p>"],
        fingerprint: 99999,
        dynamics: [
          %{deps: [], expr: {:component_call, {:component_fun, nil, :badge}, {:component_assigns, []}}}
        ]
      }

      ir = %{
        static: ["<div>", "</div>"],
        fingerprint: 12345,
        dynamics: [
          %{deps: [], expr: {:iodata, {:inner_block_ir, inner_ir, nil}}}
        ]
      }

      names = PageRenderCache.extract_component_names(ir)
      assert MapSet.member?(names, :badge)
    end

    test "returns empty set for nil input" do
      assert PageRenderCache.extract_component_names(nil) == MapSet.new()
    end

    test "returns empty set for IR with no components" do
      ir = %{
        static: ["<div>Hello</div>"],
        fingerprint: 12345,
        dynamics: []
      }

      assert PageRenderCache.extract_component_names(ir) == MapSet.new()
    end
  end

  describe "pages_for_layout/2" do
    test "returns page_id and path tuples for pages using a layout" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Page 1</div>",
        path: "/page-1",
        layout_id: "layout_1"
      })

      RuntimeRenderer.publish_page(@site, "page_2", %{
        template: "<div>Page 2</div>",
        path: "/page-2",
        layout_id: "layout_1"
      })

      deps1 = %{layout_id: "layout_1", components: MapSet.new(), data_sources: MapSet.new()}
      deps2 = %{layout_id: "layout_1", components: MapSet.new(), data_sources: MapSet.new()}

      PageRenderCache.register_page_deps(@site, "page_1", deps1)
      PageRenderCache.register_page_deps(@site, "page_2", deps2)

      pages = PageRenderCache.pages_for_layout(@site, "layout_1")
      assert length(pages) == 2
      assert {"page_1", "/page-1"} in pages
      assert {"page_2", "/page-2"} in pages
    end

    test "returns empty list for unknown layout" do
      assert PageRenderCache.pages_for_layout(@site, "unknown_layout") == []
    end
  end

  describe "pages_for_component/2" do
    test "returns page_id and path tuples for pages using a component" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Page 1</div>",
        path: "/page-1"
      })

      deps = %{layout_id: nil, components: MapSet.new([:header]), data_sources: MapSet.new()}
      PageRenderCache.register_page_deps(@site, "page_1", deps)

      pages = PageRenderCache.pages_for_component(@site, :header)
      assert [{"page_1", "/page-1"}] = pages
    end

    test "returns empty list for unknown component" do
      assert PageRenderCache.pages_for_component(@site, :unknown) == []
    end
  end

  describe "pages_for_data_source/2" do
    test "returns page_id and path tuples for pages using a data source" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Page 1</div>",
        path: "/page-1"
      })

      deps = %{layout_id: nil, components: MapSet.new(), data_sources: MapSet.new([:posts])}
      PageRenderCache.register_page_deps(@site, "page_1", deps)

      pages = PageRenderCache.pages_for_data_source(@site, :posts)
      assert [{"page_1", "/page-1"}] = pages
    end

    test "returns empty list for unknown data source" do
      assert PageRenderCache.pages_for_data_source(@site, :unknown) == []
    end
  end

  describe "invalidate_page/2" do
    test "returns :ok even when page has no manifest" do
      assert :ok = PageRenderCache.invalidate_page(@site, "unknown_page")
    end
  end

  describe "invalidate_by_layout/2" do
    test "returns :ok for unknown layout" do
      assert :ok = PageRenderCache.invalidate_by_layout(@site, "unknown_layout")
    end
  end

  describe "invalidate_by_component/2" do
    test "returns :ok for unknown component" do
      assert :ok = PageRenderCache.invalidate_by_component(@site, :unknown)
    end
  end

  describe "invalidate_by_data_source/2" do
    test "returns :ok for unknown data source" do
      assert :ok = PageRenderCache.invalidate_by_data_source(@site, :unknown)
    end
  end

  describe "publish_page integration" do
    test "publish_page automatically registers dependencies with layout" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Hello</div>",
        path: "/hello",
        layout_id: "layout_1"
      })

      # Verify the deps were registered
      [{_, stored_deps}] = :ets.lookup(@table, {@site, :dep, :page_deps, "page_1"})
      assert stored_deps.layout_id == "layout_1"
    end

    test "publish_page automatically registers data source dependencies" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Hello</div>",
        path: "/hello",
        extra: %{
          "data_sources" => [
            %{"source" => "posts"},
            %{"source" => "comments"}
          ]
        }
      })

      [{_, stored_deps}] = :ets.lookup(@table, {@site, :dep, :page_deps, "page_1"})
      assert MapSet.member?(stored_deps.data_sources, :posts)
      assert MapSet.member?(stored_deps.data_sources, :comments)
    end

    test "re-publishing page updates dependencies" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Hello</div>",
        path: "/hello",
        layout_id: "layout_1",
        extra: %{"data_sources" => [%{"source" => "posts"}]}
      })

      [{_, deps1}] = :ets.lookup(@table, {@site, :dep, :page_deps, "page_1"})
      assert deps1.layout_id == "layout_1"
      assert MapSet.member?(deps1.data_sources, :posts)

      # Re-publish with different layout and data sources
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Hello Updated</div>",
        path: "/hello",
        layout_id: "layout_2",
        extra: %{"data_sources" => [%{"source" => "comments"}]}
      })

      [{_, deps2}] = :ets.lookup(@table, {@site, :dep, :page_deps, "page_1"})
      assert deps2.layout_id == "layout_2"
      refute MapSet.member?(deps2.data_sources, :posts)
      assert MapSet.member?(deps2.data_sources, :comments)

      # Old layout reverse mapping should be cleaned up
      assert :ets.lookup(@table, {@site, :dep, :layout, "layout_1"}) == []
    end
  end
end
