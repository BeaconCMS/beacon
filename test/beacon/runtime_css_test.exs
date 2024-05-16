defmodule Beacon.RuntimeCSSTest do
  use BeaconWeb.ConnCase, async: false

  alias Beacon.RuntimeCSS

  @site :my_site

  test "load!" do
    assert RuntimeCSS.load!(@site) == :ok
    assert @site |> RuntimeCSS.fetch() |> :erlang.size() > 100
    assert RuntimeCSS.fetch(@site, :uncompressed) =~ "/* tailwind"
  end
end
