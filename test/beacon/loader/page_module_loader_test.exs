defmodule Beacon.Loader.PageModuleLoaderTest do
  use Beacon.DataCase, async: true

  import Beacon.Fixtures
  alias Beacon.Loader.PageModuleLoader
  alias Beacon.Repo

  describe "dynamic_helper" do
    test "generate each helper function and the proxy dynamic_helper" do
      page_1 = page_fixture(site: "test", path: "1")
      page_2 = page_fixture(site: "test", path: "2")

      page_helper_fixture(page_id: page_1.id, helper_name: "page_1_upcase")
      page_helper_fixture(page_id: page_2.id, helper_name: "page_2_upcase")

      page_1 = Repo.preload(page_1, [:events, :helpers])
      page_2 = Repo.preload(page_2, [:events, :helpers])

      {:ok, code_string} = PageModuleLoader.load_templates("test", [page_1, page_2])

      assert Regex.scan(~r/page_1_upcase/, code_string) == [["page_1_upcase"]]
      assert Regex.scan(~r/page_2_upcase/, code_string) == [["page_2_upcase"]]
      assert Regex.scan(~r/dynamic_helper/, code_string) == [["dynamic_helper"]]
    end
  end
end
