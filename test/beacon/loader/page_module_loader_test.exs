defmodule Beacon.Loader.PageModuleLoaderTest do
  use Beacon.DataCase, async: false

  import Beacon.Fixtures
  alias Beacon.Loader.PageModuleLoader
  alias Beacon.Repo

  describe "dynamic_helper" do
    test "generate each helper function and the proxy dynamic_helper" do
      page_1 = page_fixture(site: "my_site", path: "1")
      page_2 = page_fixture(site: "my_site", path: "2")

      page_helper_fixture(page_id: page_1.id, helper_name: "page_1_upcase")
      page_helper_fixture(page_id: page_2.id, helper_name: "page_2_upcase")

      page_1 = Repo.preload(page_1, [:events, :helpers])
      page_2 = Repo.preload(page_2, [:events, :helpers])

      {:ok, ast} = PageModuleLoader.load_templates(:test, [page_1, page_2])

      assert has_function?(ast, :page_1_upcase)
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
    test "interpolates the page title, description, and path in meta tags" do
      page_1 =
        page_fixture(
          site: "my_site",
          path: "1",
          title: "my first page",
          description: "hello world",
          meta_tags: [
            %{"property" => "og:title", "content" => "my title is %title%"},
            %{"property" => "og:description", "content" => "my description is %description%"},
            %{"property" => "og:url", "content" => "http://example.com/%path%"}
          ]
        )

      page_1 = Repo.preload(page_1, [:events, :helpers])

      {:ok, ast} = PageModuleLoader.load_templates(:test, [page_1])

      assert has_map?(ast, %{"property" => "og:title", "content" => "my title is my first page"})
      assert has_map?(ast, %{"property" => "og:description", "content" => "my description is hello world"})
      assert has_map?(ast, %{"property" => "og:url", "content" => "http://example.com/1"})
    end
  end

  defp has_map?(ast, map) do
    {_new_ast, present} =
      Macro.prewalk(ast, false, fn
        {:%{}, _, fields} = node, acc -> {node, acc or map == Map.new(fields)}
        node, acc -> {node, acc}
      end)

    present
  end
end
