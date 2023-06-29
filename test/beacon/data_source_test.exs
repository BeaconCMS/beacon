defmodule Beacon.BeaconTest.TestDataSource do
  @behaviour Beacon.DataSource.Behaviour

  def live_data(:data_source_test, ["home"], _params), do: %{vals: ["first", "second", "third"]}

  def page_title(:data_source_test, params) do
    if params.path == :raise_exeception do
      raise ArgumentError, "invalid params received"
    else
      params.page_title
    end
  end
end

defmodule Beacon.DataSourceTest do
  use Beacon.DataCase, async: true

  alias Beacon.DataSource

  describe "live_data/3" do
    test "when there isn't a live_data match" do
      error_message = """
      Could not find live_data/3 that matches the given args: [:data_source_test, [\"unkown\"], %{}].

      Make sure you have defined a implemention of Beacon.DataSource.live_data/3 that matches these args.\
      """

      assert_raise Beacon.DataSourceError, error_message, fn ->
        assert DataSource.live_data(:data_source_test, ["unkown"], %{})
      end
    end

    test "returns the data when it matches" do
      assert DataSource.live_data(:data_source_test, ["home"], %{}) == %{
               vals: ["first", "second", "third"]
             }
    end
  end

  describe "page_title/5" do
    test "re-raises if an exception is raised from mod.page_title/2" do
      error_message = """
      Exception caught during execution of page_title/2 for site :data_source_test

      ** (ArgumentError) invalid params received.
      """

      assert_raise Beacon.DataSourceError, error_message, fn ->
        DataSource.page_title(:data_source_test, :raise_exeception, %{}, %{}, "page title")
      end
    end
  end
end
