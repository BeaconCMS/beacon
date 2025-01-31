defmodule Beacon.RuntimeCSSTest do
  use Beacon.Web.ConnCase, async: true

  alias Beacon.RuntimeCSS

  @site :my_site

  test "load!" do
    assert RuntimeCSS.load!(@site) == :ok
  end

  test "fetch defaults to compressed" do
    RuntimeCSS.load!(@site)
    assert @site |> RuntimeCSS.fetch() |> :erlang.size() > 100
  end

  test "fetch uncompressed deflate" do
    RuntimeCSS.load!(@site)
    assert RuntimeCSS.fetch(@site, :deflate) =~ "/* tailwind"
  end
end
