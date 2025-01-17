defmodule Beacon.RuntimeJSTest do
  use Beacon.Web.ConnCase, async: true

  alias Beacon.RuntimeJS

  test "load" do
    assert RuntimeJS.load!() == :ok
  end

  test "fetch defaults to compressed" do
    RuntimeJS.load!()
    assert RuntimeJS.fetch() |> :erlang.size() > 100
  end

  test "fetch uncompressed deflate" do
    RuntimeJS.load!()
    assert RuntimeJS.fetch(:deflate) =~ "Beacon"
  end
end
