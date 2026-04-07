defmodule Beacon.CSS.StorageTest do
  use ExUnit.Case, async: false

  alias Beacon.CSS.Storage

  setup do
    # Ensure the ETS tables exist (Application.start creates them, but
    # if tests run in isolation we need to be defensive)
    if :ets.whereis(:beacon_assets) == :undefined do
      :ets.new(:beacon_assets, [:set, :named_table, :public, read_concurrency: true])
    end

    if :ets.whereis(:beacon_runtime_poc) == :undefined do
      :ets.new(:beacon_runtime_poc, [:set, :named_table, :public, read_concurrency: true])
    end

    # Clean up any test data
    :ets.delete_all_objects(:beacon_assets)
    :ets.delete_all_objects(:beacon_runtime_poc)

    :ok
  end

  describe "store/3" do
    test "stores CSS in ETS hot tier with hash, brotli, and gzip" do
      css = "body { color: red; }"
      candidates = MapSet.new(["text-red-500", "flex"])

      {hash, brotli, gzip} = Storage.store(:test_site, css, candidates)

      # Hash is a 32-char hex MD5
      assert byte_size(hash) == 32
      assert String.match?(hash, ~r/^[0-9a-f]{32}$/)

      # Hash is deterministic
      expected_hash = :crypto.hash(:md5, css) |> Base.encode16(case: :lower)
      assert hash == expected_hash

      # Brotli is present (ExBrotli is a dependency)
      assert is_binary(brotli)
      assert byte_size(brotli) > 0

      # Gzip decompresses back to original
      assert :zlib.gunzip(gzip) == css

      # ETS contains the stored value
      assert [{_, {^hash, ^brotli, ^gzip}}] = :ets.lookup(:beacon_assets, {:test_site, :css})
    end

    test "produces deterministic hash for same CSS" do
      css = ".flex { display: flex; }"
      candidates = MapSet.new()

      {hash1, _, _} = Storage.store(:site_a, css, candidates)
      {hash2, _, _} = Storage.store(:site_b, css, candidates)

      assert hash1 == hash2
    end

    test "produces different hash for different CSS" do
      candidates = MapSet.new()

      {hash1, _, _} = Storage.store(:site_a, "body { color: red; }", candidates)
      {hash2, _, _} = Storage.store(:site_a, "body { color: blue; }", candidates)

      refute hash1 == hash2
    end
  end

  describe "fetch/1 - ETS hot tier" do
    test "returns stored CSS from ETS" do
      css = "body { margin: 0; }"
      candidates = MapSet.new(["m-0"])

      {hash, brotli, gzip} = Storage.store(:ets_test, css, candidates)

      # Fetch should return from ETS (hot tier hit)
      assert {^hash, ^brotli, ^gzip} = Storage.fetch(:ets_test)
    end

    test "ETS lookup returns the most recent store" do
      candidates = MapSet.new()

      Storage.store(:ets_test, "old css", candidates)
      {hash2, brotli2, gzip2} = Storage.store(:ets_test, "new css", candidates)

      assert {^hash2, ^brotli2, ^gzip2} = Storage.fetch(:ets_test)
    end
  end
end
