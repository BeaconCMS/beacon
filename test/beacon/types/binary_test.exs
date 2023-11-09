defmodule Beacon.Types.BinaryTest do
  use ExUnit.Case, async: true

  alias Beacon.Types.Binary

  @term %{"foo" => :bar}
  @binary :erlang.term_to_binary(@term)

  test "cast" do
    assert Binary.cast(@binary) == {:ok, @binary}
    assert Binary.cast(@term) == {:ok, @binary}
  end

  test "dump" do
    assert Binary.dump(@binary) == {:ok, @binary}
    assert Binary.dump(@term) == {:ok, @binary}
  end

  test "load" do
    assert Binary.load(@binary) == {:ok, @term}
    assert Binary.load(@term) == :error
  end
end
