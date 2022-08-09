defmodule Beacon.DataSourceTest do
  use Beacon.DataCase, async: true

  alias Beacon.DataSource

  describe "live_data/3" do
    test "when there isn't a live_data match" do
      error_message = """
      Could not find live_data/3 that matches the given args: [\"my_site\", [\"unkown\"], %{}].

      Make sure you have defined a implemention of Beacon.DataSource.live_data/3 that matches these args.\
      """

      assert_raise Beacon.DataSource.Error, error_message, fn ->
        assert DataSource.live_data("my_site", ["unkown"], %{})
      end
    end

    test "returns the data when it matches" do
      assert DataSource.live_data("my_site", ["home"], %{}) == %{vals: ["first", "second", "third"]}
    end
  end
end
