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
end
