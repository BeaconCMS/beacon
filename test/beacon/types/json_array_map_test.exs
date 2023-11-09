defmodule Beacon.Types.JsonArrayMapTest do
  use ExUnit.Case, async: true

  alias Beacon.Types.JsonArrayMap

  @map %{"foo" => :bar}

  test "cast" do
    assert JsonArrayMap.cast(@map) == {:ok, [@map]}
    assert JsonArrayMap.cast([@map]) == {:ok, [@map]}
    assert JsonArrayMap.cast([]) == {:ok, []}
    assert JsonArrayMap.cast(nil) == {:error, [{:message, "expected a list of map or a map, got: nil"}]}
    assert JsonArrayMap.cast([1]) == {:error, [{:message, "expected a list of map or a map, got: [1]"}]}
  end

  test "dump" do
    assert JsonArrayMap.dump(@map) == {:ok, [@map]}
    assert JsonArrayMap.dump([@map]) == {:ok, [@map]}
    assert JsonArrayMap.dump([]) == {:ok, []}
    assert JsonArrayMap.dump(nil) == :error
    assert JsonArrayMap.dump([1]) == :error
  end

  test "load" do
    assert JsonArrayMap.load([@map]) == {:ok, [@map]}
    assert JsonArrayMap.load(@map) == :error
  end
end
