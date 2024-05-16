defmodule Beacon.RuntimeJSTest do
  use BeaconWeb.ConnCase, async: false

  alias Beacon.RuntimeJS

  test "load" do
    assert RuntimeJS.load!() == :ok
    assert RuntimeJS.fetch() |> :erlang.size() > 100
  end
end
