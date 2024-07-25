defmodule Beacon.RuntimeJSTest do
  use Beacon.Web.ConnCase, async: true

  alias Beacon.RuntimeJS

  test "load" do
    assert RuntimeJS.load!() == :ok
    assert RuntimeJS.fetch() |> :erlang.size() > 100
  end
end
