defmodule Beacon.Loader.DataSourceModuleLoaderTest do
  use Beacon.DataCase, async: false

  import Beacon.Fixtures

  @site :my_site

  test "basic path" do
    live_data = live_data_fixture(site: @site)
    live_data_assign_fixture(live_data, format: :text, key: "customer_id", value: "123")
    live_data_assign_fixture(live_data, format: :text, key: "customer_name", value: "Andy")

    assert assigns_for_path(live_data.path) == %{customer_id: "123", customer_name: "Andy"}
  end

  test "path with variable" do
    live_data = live_data_fixture(site: @site, path: "users/:user_id")
    live_data_assign_fixture(live_data, format: :elixir, key: "user_id", value: "String.to_integer(user_id)")

    assert assigns_for_path("users/123") == %{user_id: 123}
    assert assigns_for_path("users/9999") == %{user_id: 9999}
  end

  test "multiple paths" do
    live_data = live_data_fixture(site: @site, path: "foo")
    live_data_assign_fixture(live_data, format: :text, key: "customer_id", value: "123")
    live_data = live_data_fixture(site: @site, path: "bar")
    live_data_assign_fixture(live_data, format: :text, key: "product_id", value: "678")

    assert assigns_for_path("foo") == %{customer_id: "123"}
    assert assigns_for_path("bar") == %{product_id: "678"}
  end

  defp assigns_for_path(path) do
    {:ok, module, _ast} =
      @site
      |> Beacon.Content.live_data_for_site()
      |> Beacon.Loader.DataSourceModuleLoader.load_data_source(@site)

    path_list = String.split(path, "/", trim: true)

    module.live_data(path_list, %{})
  end
end
