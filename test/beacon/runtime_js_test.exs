defmodule Beacon.RuntimeJSTest do
  use BeaconWeb.ConnCase, async: false

  alias Beacon.RuntimeJS

  @site :my_site

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(@site)})
    :ok
  end

  test "load" do
    assert RuntimeJS.load!() == :ok
    assert RuntimeJS.fetch() |> :erlang.size() > 100
  end
end
