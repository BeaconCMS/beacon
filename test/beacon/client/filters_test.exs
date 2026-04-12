defmodule Beacon.Client.FiltersTest do
  use ExUnit.Case, async: true

  alias Beacon.Client.Filters

  describe "format_date" do
    test "formats ISO 8601 string" do
      assert Filters.apply("format_date", "2023-12-05T17:16:49Z", ["%B %d, %Y"]) == "December 05, 2023"
    end

    test "formats NaiveDateTime string" do
      assert Filters.apply("format_date", "2023-12-05T17:16:49", ["%Y-%m-%d"]) == "2023-12-05"
    end

    test "handles nil" do
      assert Filters.apply("format_date", nil, ["%B %d, %Y"]) == ""
    end
  end

  describe "truncate" do
    test "truncates long string" do
      assert Filters.apply("truncate", "Hello World", [5]) == "Hello..."
    end

    test "leaves short string unchanged" do
      assert Filters.apply("truncate", "Hi", [10]) == "Hi"
    end
  end

  describe "upcase/downcase" do
    test "upcase" do
      assert Filters.apply("upcase", "hello", []) == "HELLO"
    end

    test "downcase" do
      assert Filters.apply("downcase", "HELLO", []) == "hello"
    end
  end

  describe "strip_html" do
    test "removes tags" do
      assert Filters.apply("strip_html", "<p>Hello <b>world</b></p>", []) == "Hello world"
    end
  end

  describe "pluralize" do
    test "singular" do
      assert Filters.apply("pluralize", 1, ["post", "posts"]) == "1 post"
    end

    test "plural" do
      assert Filters.apply("pluralize", 3, ["post", "posts"]) == "3 posts"
    end
  end

  describe "format_number" do
    test "integer with thousands separator" do
      assert Filters.apply("format_number", 1234567, []) == "1,234,567"
    end

    test "float with precision" do
      result = Filters.apply("format_number", 3.14159, [2])
      assert result == "3.14"
    end
  end

  describe "collections" do
    test "size of list" do
      assert Filters.apply("size", [1, 2, 3], []) == 3
    end

    test "size of string" do
      assert Filters.apply("size", "hello", []) == 5
    end

    test "join" do
      assert Filters.apply("join", ["a", "b", "c"], [", "]) == "a, b, c"
    end

    test "first" do
      assert Filters.apply("first", [1, 2, 3], []) == 1
    end

    test "last" do
      assert Filters.apply("last", [1, 2, 3], []) == 3
    end

    test "first of empty" do
      assert Filters.apply("first", [], []) == nil
    end
  end

  describe "utility" do
    test "default with nil" do
      assert Filters.apply("default", nil, ["fallback"]) == "fallback"
    end

    test "default with empty string" do
      assert Filters.apply("default", "", ["fallback"]) == "fallback"
    end

    test "default with value" do
      assert Filters.apply("default", "present", ["fallback"]) == "present"
    end

    test "json" do
      assert Filters.apply("json", %{"a" => 1}, []) == ~s({"a":1})
    end
  end

  describe "unknown filter" do
    test "passes value through" do
      assert Filters.apply("nonexistent", "hello", []) == "hello"
    end
  end
end
