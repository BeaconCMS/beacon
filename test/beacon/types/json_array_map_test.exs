defmodule Beacon.Types.JsonArrayMapTest do
  use ExUnit.Case, async: true

  alias Beacon.Types.JsonArrayMap

  @map %{"foo" => "bar"}

  test "cast" do
    assert JsonArrayMap.cast([]) == {:ok, []}
    assert JsonArrayMap.cast(@map) == {:ok, [@map]}
    assert JsonArrayMap.cast([@map]) == {:ok, [@map]}
    assert JsonArrayMap.cast(~s|[{"foo": "bar"}]|) == {:ok, [@map]}
    assert JsonArrayMap.cast(nil) == {:error, [{:message, "expected a list of map or a map, got: nil"}]}
    assert JsonArrayMap.cast([1]) == {:error, [{:message, "expected a list of map or a map, got: [1]"}]}
    assert JsonArrayMap.cast("") == {:error, [message: "expected a list of map or a map, got error: unexpected end of input at position 0"]}
  end

  test "dump" do
    assert JsonArrayMap.dump([]) == {:ok, []}
    assert JsonArrayMap.dump(@map) == {:ok, [@map]}
    assert JsonArrayMap.dump([@map]) == {:ok, [@map]}
    assert JsonArrayMap.dump(~s|[{"foo": "bar"}]|) == {:ok, [@map]}
    assert JsonArrayMap.dump(nil) == :error
    assert JsonArrayMap.dump([1]) == :error
    assert JsonArrayMap.dump("") == :error
  end

  test "load" do
    assert JsonArrayMap.load(@map) == {:ok, [@map]}
    assert JsonArrayMap.load([@map]) == {:ok, [@map]}
    assert JsonArrayMap.load(~s|[{"foo": "bar"}]|) == {:ok, [@map]}
    assert JsonArrayMap.load(nil) == :error
    assert JsonArrayMap.load("") == :error
  end
end
