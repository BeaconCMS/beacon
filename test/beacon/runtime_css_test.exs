defmodule Beacon.RuntimeCSSTest do
  use Beacon.Web.ConnCase, async: false

  use Beacon.Test

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
    css = RuntimeCSS.fetch(@site, :deflate)
    assert is_binary(css)
    assert byte_size(css) > 100
  end

  describe "collect_all_candidates via load!" do
    test "includes candidates from published page templates" do
      beacon_published_page_fixture(
        template: ~s(<div class="underline">A</div>)
      )

      RuntimeCSS.load!(@site)
      css = RuntimeCSS.fetch(@site, :deflate)
      assert css =~ "underline"
    end
  end
end
