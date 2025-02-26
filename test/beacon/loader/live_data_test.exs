defmodule Beacon.Loader.LiveDataTest do
  use Beacon.DataCase, async: false
  use Beacon.Test, site: :my_site

  test "basic path" do
    live_data = beacon_live_data_fixture(site: default_site())
    beacon_live_data_assign_fixture(live_data: live_data, format: :text, key: "customer_id", value: "123")
    beacon_live_data_assign_fixture(live_data: live_data, format: :text, key: "customer_name", value: "Andy")

    assert assigns_for_path(live_data.path) == %{customer_id: "123", customer_name: "Andy"}
  end

  test "path with variable" do
    live_data = beacon_live_data_fixture(path: "/users/:user_id")
    beacon_live_data_assign_fixture(live_data: live_data, format: :elixir, key: "user_id", value: "String.to_integer(user_id)")

    assert assigns_for_path("/users/123") == %{user_id: 123}
  end

  test "multiple paths" do
    live_data = beacon_live_data_fixture(path: "/foo")
    beacon_live_data_assign_fixture(live_data: live_data, format: :text, key: "customer_id", value: "123")
    live_data = beacon_live_data_fixture(path: "/bar")
    beacon_live_data_assign_fixture(live_data: live_data, format: :text, key: "product_id", value: "678")

    assert assigns_for_path("/foo") == %{customer_id: "123"}
    assert assigns_for_path("/bar") == %{product_id: "678"}
  end

  test "forward errors" do
    live_data = beacon_live_data_fixture(path: "/error")
    beacon_live_data_assign_fixture(live_data: live_data, format: :elixir, key: "test", value: "String.foo()")

    assert_raise UndefinedFunctionError, "function String.foo/0 is undefined or private", fn ->
      assert assigns_for_path("/error")
    end
  end

  defp assigns_for_path(path) do
    path_list = String.split(path, "/", trim: true)
    module = Beacon.Loader.fetch_live_data_module(default_site())
    module.live_data(path_list, %{})
  end
end
