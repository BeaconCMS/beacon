defmodule Beacon.Loader.PageTest do
  use Beacon.DataCase, async: false
  import Beacon.Fixtures
  alias Beacon.Loader
  alias Beacon.Repo

  describe "dynamic_helper" do
    test "generate each helper function and the proxy dynamic_helper" do
      page_1 = published_page_fixture(site: "my_site", path: "/1", helpers: [page_helper_params(name: "page_1_upcase")])
      page_2 = published_page_fixture(site: "my_site", path: "/2", helpers: [page_helper_params(name: "page_2_upcase")])

      module_1 = Loader.reload_page_module(page_1.site, page_1.id)
      assert {:dynamic_helper, 2} in module_1.__info__(:functions)
      assert {:page_1_upcase, 1} in module_1.__info__(:functions)

      module_2 = Loader.reload_page_module(page_2.site, page_2.id)
      assert {:dynamic_helper, 2} in module_2.__info__(:functions)
      assert {:page_2_upcase, 1} in module_2.__info__(:functions)
    end
  end

  describe "page_assigns/1" do
    test "interpolates raw_schema snippets" do
      snippet_helper_fixture(%{
        site: "my_site",
        name: "raw_schema_blog_post_tags",
        body: ~S"""
        tags = get_in(assigns, ["page", "extra", "tags"])
        String.upcase(tags)
        """
      })

      layout = published_layout_fixture()

      page =
        published_page_fixture(
          site: "my_site",
          layout_id: layout.id,
          path: "/page/raw-schema",
          title: "my first page",
          description: "hello world",
          extra: %{
            "tags" => "beacon,test"
          },
          raw_schema: [
            %{
              "@context": "https://schema.org",
              "@type": "BlogPosting",
              headline: "{{ page.description }}",
              keywords: "{% helper 'raw_schema_blog_post_tags' %}"
            }
          ]
        )

      page_module = Loader.reload_page_module(page.site, page.id)

      [raw_schema] = page_module.page_assigns().raw_schema

      assert Enum.sort(raw_schema) == [
               "@context": "https://schema.org",
               "@type": "BlogPosting",
               headline: "hello world",
               keywords: "BEACON,TEST"
             ]
    end
  end

  describe "render" do
    test "render primary template" do
      page = published_page_fixture(site: "my_site", path: "/1") |> Repo.preload([:event_handlers, :variants])
      module = Loader.reload_page_module(page.site, page.id)
      assert %Phoenix.LiveView.Rendered{static: ["<main>\n  <h1>my_site#home</h1>\n</main>"]} = module.render(%{})
    end

    test "render all templates" do
      page = published_page_fixture(site: "my_site", path: "/1")
      Beacon.Content.create_variant_for_page(page, %{name: "variant_a", weight: 1, template: "<div>variant_a</div>"})
      Beacon.Content.create_variant_for_page(page, %{name: "variant_b", weight: 2, template: "<div>variant_b</div>"})
      Beacon.Content.publish_page(page)
      module = Loader.reload_page_module(page.site, page.id)

      assert [
               %Phoenix.LiveView.Rendered{static: ["<main>\n  <h1>my_site#home</h1>\n</main>"]},
               {1, %Phoenix.LiveView.Rendered{static: ["<div>variant_a</div>"]}},
               {2, %Phoenix.LiveView.Rendered{static: ["<div>variant_b</div>"]}}
             ] = module.templates(%{})
    end
  end
end
