defmodule Beacon.GraphQL.TypeCoercionTest do
  use ExUnit.Case, async: true

  alias Beacon.GraphQL.TypeCoercion

  describe "coerce/2" do
    test "coerces string to Int" do
      assert TypeCoercion.coerce("42", %{"kind" => "SCALAR", "name" => "Int"}) == 42
    end

    test "coerces string to Float" do
      assert TypeCoercion.coerce("3.14", %{"kind" => "SCALAR", "name" => "Float"}) == 3.14
    end

    test "coerces string to Boolean" do
      assert TypeCoercion.coerce("true", %{"kind" => "SCALAR", "name" => "Boolean"}) == true
      assert TypeCoercion.coerce("false", %{"kind" => "SCALAR", "name" => "Boolean"}) == false
    end

    test "passes String through" do
      assert TypeCoercion.coerce("hello", %{"kind" => "SCALAR", "name" => "String"}) == "hello"
    end

    test "passes ID through" do
      assert TypeCoercion.coerce("abc-123", %{"kind" => "SCALAR", "name" => "ID"}) == "abc-123"
    end

    test "unwraps NON_NULL" do
      type = %{"kind" => "NON_NULL", "ofType" => %{"kind" => "SCALAR", "name" => "Int"}}
      assert TypeCoercion.coerce("5", type) == 5
    end

    test "handles LIST by splitting" do
      type = %{"kind" => "LIST", "ofType" => %{"kind" => "SCALAR", "name" => "Int"}}
      assert TypeCoercion.coerce("1,2,3", type) == [1, 2, 3]
    end

    test "returns nil for nil input" do
      assert TypeCoercion.coerce(nil, %{"kind" => "SCALAR", "name" => "String"}) == nil
    end

    test "passes through already-typed values" do
      assert TypeCoercion.coerce(42, %{"kind" => "SCALAR", "name" => "Int"}) == 42
    end
  end

  describe "base_type/1" do
    test "unwraps NON_NULL to scalar" do
      type = %{"kind" => "NON_NULL", "ofType" => %{"kind" => "SCALAR", "name" => "String"}}
      assert TypeCoercion.base_type(type) == {:scalar, "String"}
    end

    test "unwraps LIST" do
      type = %{"kind" => "LIST", "ofType" => %{"kind" => "SCALAR", "name" => "Int"}}
      assert TypeCoercion.base_type(type) == {:list, {:scalar, "Int"}}
    end

    test "returns enum type" do
      assert TypeCoercion.base_type(%{"kind" => "ENUM", "name" => "Status"}) == {:enum, "Status"}
    end
  end

  describe "required?/1" do
    test "NON_NULL is required" do
      assert TypeCoercion.required?(%{"kind" => "NON_NULL", "ofType" => %{}})
    end

    test "other types are not required" do
      refute TypeCoercion.required?(%{"kind" => "SCALAR", "name" => "String"})
    end
  end
end
