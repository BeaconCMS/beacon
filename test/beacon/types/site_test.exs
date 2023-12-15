defmodule Beacon.Types.SiteTest do
  use ExUnit.Case, async: true

  alias Beacon.Types.Site
  import Beacon.Types.Site, only: [valid?: 1]

  doctest Site, only: [valid?: 1]

  _ = :site

  test "cast" do
    assert Site.cast("site") == {:ok, :site}
    assert Site.cast(:site) == {:ok, :site}
    assert Site.cast(0) == {:error, [message: "invalid site 0"]}
  end

  test "dump" do
    assert Site.dump("site") == {:ok, "site"}
    assert Site.dump(:site) == {:ok, "site"}
    assert Site.dump(0) == :error
  end

  test "load" do
    assert Site.load("site") == {:ok, :site}
    assert Site.load(0) == :error
  end

  describe "valid_name?/1" do
    test "SUCCESS: Return TRUE if it is a valid name" do
      assert Site.valid_name?("some_name")
    end

    test "SUCCESS: Return FALSE if it is an invalid name" do
      refute Site.valid_name?("beacon_some_name")
    end
  end
end
