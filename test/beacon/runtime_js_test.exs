defmodule Beacon.RuntimeJSTest do
  use Beacon.Web.ConnCase, async: true

  alias Beacon.RuntimeJS

  @site :my_site

  test "load" do
    assert RuntimeJS.load!(@site) == :ok
  end

  test "fetch defaults to compressed" do
    RuntimeJS.load!(@site)
    assert RuntimeJS.fetch(@site) |> :erlang.size() > 100
  end

  test "fetch uncompressed deflate" do
    RuntimeJS.load!(@site)
    assert RuntimeJS.fetch(@site, :deflate) =~ "Beacon"
  end

  describe "build_hooks/2" do
    setup do
      beacon_js_hook_fixture(name: "Hook1")
      beacon_js_hook_fixture(name: "Hook2")
      :ok
    end

    test "default" do
      assert RuntimeJS.build_hooks(@site, _minify = false) ==
               """
                   Hook1: {
                     mounted() {
                       console.log("mounted!");
                     },
                   },
                   Hook2: {
                     mounted() {
                       console.log("mounted!");
                     },
                   }\
               """
    end

    test "minified" do
      assert RuntimeJS.build_hooks(@site, _minify = true) ==
               "Hook1:{mounted(){console.log(\"mounted!\");},},Hook2:{mounted(){console.log(\"mounted!\");},}"
    end
  end
end
