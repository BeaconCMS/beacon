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
        graphql_endpoints: MapSet.new(["blog_api"])
      }

      :ok = PageRenderCache.register_page_deps(@site, "page_1", deps)

      [{_, layout_pages}] = :ets.lookup(@table, {@site, :dep, :layout, "layout_1"})
      assert MapSet.member?(layout_pages, "page_1")

      [{_, header_pages}] = :ets.lookup(@table, {@site, :dep, :component, :header})
      assert MapSet.member?(header_pages, "page_1")

      [{_, footer_pages}] = :ets.lookup(@table, {@site, :dep, :component, :footer})
      assert MapSet.member?(footer_pages, "page_1")

      [{_, endpoint_pages}] = :ets.lookup(@table, {@site, :dep, :graphql_endpoint, "blog_api"})
      assert MapSet.member?(endpoint_pages, "page_1")

      [{_, stored_deps}] = :ets.lookup(@table, {@site, :dep, :page_deps, "page_1"})
      assert stored_deps.layout_id == "layout_1"
      assert MapSet.member?(stored_deps.components, :header)
      assert MapSet.member?(stored_deps.graphql_endpoints, "blog_api")
    end

    test "removes old dependencies when re-registering" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Hello</div>",
        path: "/hello",
        layout_id: "layout_1"
      })

      deps1 = %{
        layout_id: "layout_1",
        components: MapSet.new([:header]),
        graphql_endpoints: MapSet.new(["blog_api"])
      }
      :ok = PageRenderCache.register_page_deps(@site, "page_1", deps1)

      deps2 = %{
        layout_id: "layout_2",
        components: MapSet.new([:sidebar]),
        graphql_endpoints: MapSet.new(["shop_api"])
      }
      :ok = PageRenderCache.register_page_deps(@site, "page_1", deps2)

      assert :ets.lookup(@table, {@site, :dep, :layout, "layout_1"}) == []
      assert :ets.lookup(@table, {@site, :dep, :component, :header}) == []
      assert :ets.lookup(@table, {@site, :dep, :graphql_endpoint, "blog_api"}) == []

      [{_, layout_pages}] = :ets.lookup(@table, {@site, :dep, :layout, "layout_2"})
      assert MapSet.member?(layout_pages, "page_1")

      [{_, sidebar_pages}] = :ets.lookup(@table, {@site, :dep, :component, :sidebar})
      assert MapSet.member?(sidebar_pages, "page_1")

      [{_, shop_pages}] = :ets.lookup(@table, {@site, :dep, :graphql_endpoint, "shop_api"})
      assert MapSet.member?(shop_pages, "page_1")
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

      deps1 = %{layout_id: "layout_1", components: MapSet.new()}
      deps2 = %{layout_id: "layout_1", components: MapSet.new()}

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

      deps = %{layout_id: "layout_1", components: MapSet.new()}
      :ok = PageRenderCache.register_page_deps(@site, "page_1", deps)
      :ok = PageRenderCache.register_page_deps(@site, "page_2", deps)

      new_deps = %{layout_id: "layout_2", components: MapSet.new()}
      :ok = PageRenderCache.register_page_deps(@site, "page_1", new_deps)

      [{_, layout_pages}] = :ets.lookup(@table, {@site, :dep, :layout, "layout_1"})
      refute MapSet.member?(layout_pages, "page_1")
      assert MapSet.member?(layout_pages, "page_2")
    end
  end

  describe "extract_component_names/1" do
    test "extracts CMS component names from IR" do
      ir = [
        {:component, :header, [], []},
        {:component, :footer, [], []},
        {:tag, "div", [], [{:text, "hello"}]}
      ]

      names = PageRenderCache.extract_component_names(ir)
      assert MapSet.member?(names, :header)
      assert MapSet.member?(names, :footer)
    end

    test "extracts components from nested rendered blocks" do
      ir = [
        {:tag, "div", [], [
          {:component, :sidebar, [], []}
        ]}
      ]

      names = PageRenderCache.extract_component_names(ir)
      assert MapSet.member?(names, :sidebar)
    end

    test "extracts components from for expressions" do
      ir = [
        {:eex_block, "for item <- @items", [
          {:component, :card, [], []}
        ]}
      ]

      names = PageRenderCache.extract_component_names(ir)
      assert MapSet.member?(names, :card)
    end

    test "extracts components from inner blocks" do
      ir = [
        {:tag, "div", [], [
          {:component, :badge, [], []}
        ]}
      ]

      names = PageRenderCache.extract_component_names(ir)
      assert MapSet.member?(names, :badge)
    end

    test "returns empty set for nil input" do
      assert PageRenderCache.extract_component_names(nil) == MapSet.new()
    end

    test "returns empty set for IR with no components" do
      ir = [{:tag, "div", [], [{:text, "Hello"}]}]
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

      deps1 = %{layout_id: "layout_1", components: MapSet.new()}
      deps2 = %{layout_id: "layout_1", components: MapSet.new()}

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

      deps = %{layout_id: nil, components: MapSet.new([:header])}
      PageRenderCache.register_page_deps(@site, "page_1", deps)

      pages = PageRenderCache.pages_for_component(@site, :header)
      assert [{"page_1", "/page-1"}] = pages
    end

    test "returns empty list for unknown component" do
      assert PageRenderCache.pages_for_component(@site, :unknown) == []
    end
  end

  describe "pages_for_graphql_endpoint/2" do
    test "returns page_id and path tuples for pages using an endpoint" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Page 1</div>",
        path: "/page-1"
      })

      deps = %{layout_id: nil, components: MapSet.new(), graphql_endpoints: MapSet.new(["blog_api"])}
      PageRenderCache.register_page_deps(@site, "page_1", deps)

      pages = PageRenderCache.pages_for_graphql_endpoint(@site, "blog_api")
      assert [{"page_1", "/page-1"}] = pages
    end

    test "returns empty list for unknown endpoint" do
      assert PageRenderCache.pages_for_graphql_endpoint(@site, "unknown") == []
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

  describe "invalidate_by_graphql_endpoint/2" do
    test "returns :ok for unknown endpoint" do
      assert :ok = PageRenderCache.invalidate_by_graphql_endpoint(@site, "unknown")
    end
  end

  describe "publish_page integration" do
    test "publish_page automatically registers dependencies with layout" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Hello</div>",
        path: "/hello",
        layout_id: "layout_1"
      })

      [{_, stored_deps}] = :ets.lookup(@table, {@site, :dep, :page_deps, "page_1"})
      assert stored_deps.layout_id == "layout_1"
    end

    test "re-publishing page updates dependencies" do
      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Hello</div>",
        path: "/hello",
        layout_id: "layout_1"
      })

      [{_, deps1}] = :ets.lookup(@table, {@site, :dep, :page_deps, "page_1"})
      assert deps1.layout_id == "layout_1"

      RuntimeRenderer.publish_page(@site, "page_1", %{
        template: "<div>Hello Updated</div>",
        path: "/hello",
        layout_id: "layout_2"
      })

      [{_, deps2}] = :ets.lookup(@table, {@site, :dep, :page_deps, "page_1"})
      assert deps2.layout_id == "layout_2"

      assert :ets.lookup(@table, {@site, :dep, :layout, "layout_1"}) == []
    end
  end
end
