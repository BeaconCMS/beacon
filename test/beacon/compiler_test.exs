defmodule Beacon.CompilerTest do
  use ExUnit.Case, async: true

  alias Beacon.Compiler

  @site :my_site

  setup do
    valid_quoted_v1 =
      quote do
        defmodule Valid do
          def foo do
            :bar_v1
          end
        end
      end

    valid_quoted_v2 =
      quote do
        defmodule Valid do
          def foo do
            :bar_v2
          end
        end
      end

    error_quoted =
      quote do
        defmodule Invalid do
          foo
        end
      end

    on_exit(fn -> Compiler.unload(Valid) end)

    [valid_quoted_v1: valid_quoted_v1, valid_quoted_v2: valid_quoted_v2, error_quoted: error_quoted]
  end

  test "extracts module name from quoted expression", %{valid_quoted_v1: quoted} do
    assert Compiler.module_name(quoted) == {:ok, Valid}
  end

  test "compiles valid quoted expressions", %{valid_quoted_v1: quoted} do
    assert {:ok, mod, []} = Compiler.compile_module(@site, quoted)
    assert mod.foo() == :bar_v1
  end

  test "returns module loaded in memory", %{valid_quoted_v1: quoted} do
    assert {:ok, mod, []} = Compiler.compile_module(@site, quoted)
    assert mod.foo() == :bar_v1

    assert {:ok, mod, []} = Compiler.compile_module(@site, quoted)
    assert mod.foo() == :bar_v1
  end

  test "updates module", %{valid_quoted_v1: quoted_v1, valid_quoted_v2: quoted_v2} do
    assert {:ok, mod, []} = Compiler.compile_module(@site, quoted_v1)
    assert mod.foo() == :bar_v1

    assert {:ok, mod, []} = Compiler.compile_module(@site, quoted_v2)
    assert mod.foo() == :bar_v2
  end

  if Version.match?(System.version(), ">= 1.15.0") do
    test "returns errors", %{error_quoted: quoted} do
      assert {:error, Invalid, {%CompileError{description: description}, [%{message: message}]}} = Compiler.compile_module(@site, quoted)
      assert description =~ "cannot compile module"
      assert message =~ "undefined variable"
    end
  end

  if Version.match?(System.version(), "< 1.15.0") do
    test "returns errors", %{error_quoted: quoted} do
      assert {:error, Invalid, {%CompileError{description: description}, []}} = Compiler.compile_module(@site, quoted)
      assert description =~ "undefined function foo"
    end
  end
end
