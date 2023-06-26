defmodule Beacon.Loader.PageModuleLoaderTest do
  use Beacon.DataCase, async: false

  import Beacon.Fixtures
  alias Beacon.Loader.PageModuleLoader

  describe "dynamic_helper" do
    test "generate each helper function and the proxy dynamic_helper" do
      page_1 = page_fixture(site: "my_site", path: "1", helpers: [page_helper_params(name: "page_1_upcase")])
      page_2 = page_fixture(site: "my_site", path: "2", helpers: [page_helper_params(name: "page_2_upcase")])

      {:ok, ast} = PageModuleLoader.load_page!(page_1)
      assert has_function?(ast, :page_1_upcase)
      assert has_function?(ast, :dynamic_helper)

      {:ok, ast} = PageModuleLoader.load_page!(page_2)
      assert has_function?(ast, :page_2_upcase)
      assert has_function?(ast, :dynamic_helper)
    end
  end

  defp has_function?(ast, helper_name) do
    {_new_ast, present} =
      Macro.prewalk(ast, false, fn
        {^helper_name, _, _} = node, _acc -> {node, true}
        node, true -> {node, true}
        node, false -> {node, false}
      end)

    present
  end

  describe "page_assigns/1" do
    defp start_loader(_) do
      start_supervised!({Beacon.Loader, Beacon.Config.fetch!(:my_site)})
      :ok
    end

    setup [:start_loader]

    test "interpolates meta tag snippets" do
      snippet_helper_fixture(%{
        site: "my_site",
        name: "og_description",
        body: ~S"""
        assigns
        |> get_in(["page", "description"])
        |> String.upcase()
        """
      })

      layout = published_layout_fixture()

      page =
        published_page_fixture(
          site: "my_site",
          layout_id: layout.id,
          path: "page/meta-tag",
          title: "my first page",
          description: "my test page",
          meta_tags: [
            %{"property" => "og:description", "content" => "{% helper 'og_description' %}"},
            %{"property" => "og:url", "content" => "http://example.com/{{ page.path }}"}
          ]
        )

      Beacon.Loader.load_page(page)

      {:ok, ast} = PageModuleLoader.load_page!(page)

      assert has_fields?(ast, [{"content", "MY TEST PAGE"}, {"property", "og:description"}])
      assert has_fields?(ast, [{"content", "http://example.com/page/meta-tag"}, {"property", "og:url"}])
    end

    test "interpolates raw_schema snippets" do
      snippet_helper_fixture(%{
        site: "my_site",
        name: "author_name",
        body: ~S"""
        author_id =  get_in(assigns, ["page", "extra", "author_id"])
        "author_#{author_id}"
        """
      })

      layout = published_layout_fixture()

      page =
        published_page_fixture(
          site: "my_site",
          layout_id: layout.id,
          path: "page/raw-schema",
          title: "my first page",
          description: "hello world",
          extra: %{
            "author_id" => 1
          },
          raw_schema: [
            %{
              "@context": "https://schema.org",
              "@type": "BlogPosting",
              headline: "{{ page.description }}",
              author: %{
                "@type": "Person",
                name: "{% helper 'author_name' %}"
              }
            }
          ]
        )

      Beacon.Loader.load_page(page)

      {:ok, ast} = PageModuleLoader.load_page!(page)

      assert has_fields?(ast,
               "@context": "https://schema.org",
               "@type": "BlogPosting",
               author: {:%{}, [], ["@type": "Person", name: "author_1"]},
               headline: "hello world"
             )
    end
  end

  defp has_fields?(ast, match) do
    {_new_ast, present} =
      Macro.prewalk(ast, false, fn
        {:%{}, _, fields} = node, acc -> {node, acc or match == Enum.sort(fields)}
        node, acc -> {node, acc}
      end)

    present
  end
end
