defmodule Beacon.LayoutsTest do
  use Beacon.DataCase

  import Beacon.Fixtures
  alias Beacon.Layouts

  describe "list_distinct_sites_from_layouts/0" do
    test "list distinct sites" do
      for site <- ["site_01", "site_02", "site_01"] do
        create_layout(%{site: site})
      end

      assert [:site_01, :site_02] = Layouts.list_distinct_sites_from_layouts()
    end
  end

  defp create_layout(attrs) do
    layout_fixture(attrs)
  end
end
