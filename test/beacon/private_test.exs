defmodule Beacon.PrivateTest do
  use Beacon.Web.ConnCase, async: true
  use Beacon.Test, site: :my_site

  setup do
    beacon_page_fixture(path: "/on_mount")

    :ok
  end

  test "router assigns" do
    assert Beacon.Private.route_assigns(default_site(), "/on_mount") == %{
             on_mount_var: "on_mount_test"
           }
  end
end
