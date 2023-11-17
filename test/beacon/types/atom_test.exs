defmodule Beacon.Types.AtomTest do
  use ExUnit.Case, async: true

  alias Beacon.Types.Atom

  _ = :site

  test "cast" do
    assert Atom.cast("site") == {:ok, :site}
    assert Atom.cast(:site) == {:ok, :site}
    assert Atom.cast(0) == {:error, [message: "invalid site 0"]}
  end

  test "dump" do
    assert Atom.dump("site") == {:ok, "site"}
    assert Atom.dump(:site) == {:ok, "site"}
    assert Atom.dump(0) == :error
  end

  test "load" do
    assert Atom.load("site") == {:ok, :site}
    assert Atom.load(0) == :error
  end
end
