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
      beacon_js_hook_fixture(
        name: "Hook1",
        code: ~S"""
        export const CloseOnGlobalClick = {
          mounted() {
            this.button = this.el.querySelector("button");
            this.handle = () => {
              if (this.button.matches("[data-opened]")) {
                this.button.click();
              }
            };
            window.addEventListener("click", this.handle);
          },

          destroyed() {
            window.removeEventListener("click", this.handle);
          },
        };
        """
      )

      beacon_js_hook_fixture(
        name: "Hook2",
        code: ~S"""
        export const InvalidZipDisplay = {
          mounted() {
            this.handleEvent("invalid-zip", e => {
              this.el.setCustomValidity(e.message);
            })
            this.handleEvent("valid-zip", e => {
              this.el.setCustomValidity('');
            })
          }
        }
        """
      )

      :ok
    end

    @tag :skip
    test "default" do
      assert RuntimeJS.build_hooks(@site, _minify = false) ==
               """
                   Hook1: {
                     mounted() {
                       console.log("mounted!");
                       console.log("second line");
                     },
                     updated() {
                       console.log("updated!");
                     },
                   },
                   Hook2: {
                     beforeUpdate() {
                       console.log("before update!");
                     },
                   }\
               """
    end

    @tag :skip
    test "minified" do
      assert RuntimeJS.build_hooks(@site, _minify = true) ==
               "Hook1:{mounted(){console.log(\"mounted!\");console.log(\"second line\");},updated(){console.log(\"updated!\");},},Hook2:{beforeUpdate(){console.log(\"before update!\");},}"
    end
  end
end
