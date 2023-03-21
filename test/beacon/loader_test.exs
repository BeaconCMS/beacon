defmodule Beacon.LoaderTest do
  use ExUnit.Case, async: true
  alias Beacon.Loader

  @tag capture_log: true
  test "reload_module! validates ast" do
    ast =
      quote do
        defmodule Foo.Bar do
          def
        end
      end

    assert_raise Beacon.LoaderError, "Failed to load module Foo.Bar, got: nofile: undefined function def/0 (there is no such import)", fn ->
      Loader.reload_module!(Foo.Bar, ast)
    end
  end
end
