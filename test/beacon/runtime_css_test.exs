defmodule Beacon.RuntimeCSSTest do
  use BeaconWeb.ConnCase, async: false

  alias Beacon.RuntimeCSS

  @site :my_site

  setup_all do
    start_supervised!({Beacon.Loader, Beacon.Config.fetch!(@site)})
    :ok
  end

  test "load!" do
    assert RuntimeCSS.load!(@site) == :ok
    assert @site |> RuntimeCSS.fetch() |> :erlang.size() > 100
  end
end
