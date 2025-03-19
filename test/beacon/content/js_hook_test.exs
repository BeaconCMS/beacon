defmodule Beacon.Content.JSHookTest do
  use Beacon.DataCase, async: true
  use Beacon.Test, site: :my_site

  alias Beacon.Content.JSHook

  describe "validate_code" do
    test "success (named hook)" do
      attrs = %{
        site: default_site(),
        name: "FooHook",
        code: """
        export const FooHook = {
          mounted() {
            console.log("mounted");
          }
        }
        """
      }

      changeset = JSHook.changeset(%JSHook{}, attrs)

      assert changeset.valid? == true
      assert changeset.errors == []
    end

    test "success (default hook)" do
      attrs = %{
        site: default_site(),
        name: "FooHook",
        code: """
        const BarHook = { mounted() { console.log("mounted") } }

        export default BarHook
        """
      }

      changeset = JSHook.changeset(%JSHook{}, attrs)

      assert changeset.valid? == true
      assert changeset.errors == []
    end

    test "success (object)" do
      attrs = %{
        site: default_site(),
        name: "FooHook",
        code: """
        const FooHook = { mounted() { console.log("mounted") } }

        export { FooHook };
        """
      }

      changeset = JSHook.changeset(%JSHook{}, attrs)

      assert changeset.valid? == true
      assert changeset.errors == []
    end

    test "error (name mismatch)" do
      attrs = %{
        site: default_site(),
        name: "FooHook",
        code: """
        export const BarHook = {
          mounted() {
            console.log("mounted");
          }
        }
        """
      }

      changeset = JSHook.changeset(%JSHook{}, attrs)

      assert changeset.valid? == false
      assert changeset.errors == [name: {"does not match export", [export: "BarHook"]}]
    end

    test "error (no export)" do
      attrs = %{
        site: default_site(),
        name: "FooHook",
        code: """
        const FooHook = {
          mounted() {
            console.log("mounted");
          }
        }
        """
      }

      changeset = JSHook.changeset(%JSHook{}, attrs)

      assert changeset.valid? == false
      assert changeset.errors == [code: {"no export found", []}]
    end

    test "error (multiple exports)" do
      attrs = %{
        site: default_site(),
        name: "FooHook",
        code: """
        export const FooHook = { mounted() { console.log("foo") } }
        export const BarHook = { mounted() { console.log("bar") } }
        """
      }

      changeset = JSHook.changeset(%JSHook{}, attrs)

      assert changeset.valid? == false
      assert changeset.errors == [code: {"multiple exports are not allowed", []}]
    end

    test "error (multiple hooks in export)" do
      attrs = %{
        site: default_site(),
        name: "FooHook",
        code: """
        const FooHook = { mounted() { console.log("foo") } }
        const BarHook = { mounted() { console.log("bar") } }

        export { FooHook, BarHook }
        """
      }

      changeset = JSHook.changeset(%JSHook{}, attrs)

      assert changeset.valid? == false
      assert changeset.errors == [code: {"multiple exports are not allowed", []}]
    end
  end
end
