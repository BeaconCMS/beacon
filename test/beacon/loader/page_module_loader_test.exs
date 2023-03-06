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
end
