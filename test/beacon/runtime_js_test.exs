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

  describe "build/1" do
    setup do
      beacon_js_hook_fixture(
        name: "CloseOnGlobalClick",
        code: ~S"""
        const MyHook = {
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

        export default MyHook;
        """
      )

      beacon_js_hook_fixture(
        name: "InvalidZipDisplay",
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

    test "success" do
      js = RuntimeJS.build(@site)

      assert js =~
               """
                 var hooks_exports = {};
                 __export(hooks_exports, {
                   default: () => hooks_default
                 });
               """

      assert js =~
               """
                 var InvalidZipDisplay = {
                   mounted() {
                     this.handleEvent(\"invalid-zip\", (e) => {
                       this.el.setCustomValidity(e.message);
                     });
                     this.handleEvent(\"valid-zip\", (e) => {
                       this.el.setCustomValidity(\"\");
                     });
                   }
                 };
               """

      assert js =~
               """
                 var MyHook = {
                   mounted() {
                     this.button = this.el.querySelector(\"button\");
                     this.handle = () => {
                       if (this.button.matches(\"[data-opened]\")) {
                         this.button.click();
                       }
                     };
                     window.addEventListener(\"click\", this.handle);
                   },
                   destroyed() {
                     window.removeEventListener(\"click\", this.handle);
                   }
                 };
                 var CloseOnGlobalClick_default = MyHook;
               """

      assert js =~
               """
                 var hooks_default = {
                   InvalidZipDisplay,
                   CloseOnGlobalClick: CloseOnGlobalClick_default
                 };
               """

      assert js =~
               """
                 return __toCommonJS(hooks_exports);
               """
    end
  end
end
