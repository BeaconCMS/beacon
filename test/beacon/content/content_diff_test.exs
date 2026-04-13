defmodule Beacon.Content.ContentDiffTest do
  use ExUnit.Case, async: true

  alias Beacon.Content.ContentDiff

  describe "tokenize/1" do
    test "splits text into lowercase word tokens" do
      tokens = ContentDiff.tokenize("Hello World Foo Bar")
      assert tokens == ["hello", "world", "foo", "bar"]
    end

    test "strips HTML tags" do
      tokens = ContentDiff.tokenize("<h1>Title</h1><p>Content here</p>")
      assert "title" in tokens
      assert "content" in tokens
      assert "here" in tokens
      refute "<h1>" in tokens
    end

    test "strips Beacon interpolation syntax" do
      tokens = ContentDiff.tokenize("Hello {{ post.title }} world {% helper 'test' %}")
      assert tokens == ["hello", "world"]
    end

    test "handles empty string" do
      assert ContentDiff.tokenize("") == []
    end
  end
end
