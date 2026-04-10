defmodule Beacon.DataStoreTest do
  use ExUnit.Case, async: false

  alias Beacon.DataStore
  alias Beacon.DataStore.Source

  @table :beacon_runtime_poc

  setup do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:set, :named_table, :public, read_concurrency: true])
    end

    # Clean up any data_store entries
    :ets.match_delete(@table, {{:test_site, :data_store, :_, :_, :_}, :_})
    :ets.delete_all_objects(:beacon_assets)

    :ok
  end

  describe "Source.new!/1" do
    test "builds a valid source" do
      source = Source.new!(name: :posts, fetch: {MyApp, :list_posts, []}, ttl: 60_000)
      assert source.name == :posts
      assert source.fetch == {MyApp, :list_posts, []}
      assert source.ttl == 60_000
      assert source.params == []
      assert source.cache_key == :params_hash
      assert source.invalidate_on == []
    end

    test "validates required fields" do
      assert_raise ArgumentError, ~r/name/, fn -> Source.new!(fetch: {M, :f, []}, ttl: 1000) end
      assert_raise ArgumentError, ~r/fetch/, fn -> Source.new!(name: :x, ttl: 1000) end
      assert_raise ArgumentError, ~r/ttl/, fn -> Source.new!(name: :x, fetch: {M, :f, []}) end
    end

    test "accepts custom cache_key function" do
      key_fn = fn params -> params[:slug] end
      source = Source.new!(name: :post, fetch: {M, :f, [:slug]}, ttl: 1000, cache_key: key_fn)
      assert is_function(source.cache_key, 1)
    end

    test "accepts invalidate_on topics" do
      source = Source.new!(name: :posts, fetch: {M, :f, []}, ttl: 1000, invalidate_on: ["blog:updated"])
      assert source.invalidate_on == ["blog:updated"]
    end
  end

  describe "register/2" do
    test "stores source definitions in ETS" do
      sources = [
        Source.new!(name: :posts, fetch: {MyApp, :list_posts, []}, ttl: 60_000),
        Source.new!(name: :users, fetch: {MyApp, :list_users, []}, ttl: 120_000)
      ]

      assert :ok = DataStore.register(:test_site, sources)
      assert %{posts: _, users: _} = DataStore.get_sources(:test_site)
    end
  end

  describe "fetch/3" do
    setup do
      # Register a source that calls a test function
      Agent.start_link(fn -> 0 end, name: :fetch_counter)

      sources = [
        Source.new!(
          name: :counter,
          fetch: fn _params ->
            Agent.update(:fetch_counter, &(&1 + 1))
            Agent.get(:fetch_counter, & &1)
          end,
          ttl: 60_000
        )
      ]

      DataStore.register(:test_site, sources)

      on_exit(fn ->
        if pid = Process.whereis(:fetch_counter) do
          if Process.alive?(pid), do: Agent.stop(:fetch_counter)
        end
      end)

      :ok
    end

    test "fetches data on cache miss" do
      result = DataStore.fetch(:test_site, :counter)
      assert result == 1
    end

    test "returns cached data on cache hit" do
      assert DataStore.fetch(:test_site, :counter) == 1
      assert DataStore.fetch(:test_site, :counter) == 1
      # Fetcher was only called once
      assert Agent.get(:fetch_counter, & &1) == 1
    end

    test "caches separately per params" do
      sources = [
        Source.new!(
          name: :echo,
          fetch: fn params -> params end,
          ttl: 60_000,
          params: [:id]
        )
      ]

      DataStore.register(:test_site, sources)

      assert DataStore.fetch(:test_site, :echo, %{id: 1}) == %{id: 1}
      assert DataStore.fetch(:test_site, :echo, %{id: 2}) == %{id: 2}
    end
  end

  describe "invalidate/2" do
    setup do
      sources = [
        Source.new!(
          name: :data,
          fetch: fn _params -> System.monotonic_time() end,
          ttl: 60_000
        )
      ]

      DataStore.register(:test_site, sources)
      :ok
    end

    test "busts all cache entries for a source" do
      val1 = DataStore.fetch(:test_site, :data)
      assert DataStore.fetch(:test_site, :data) == val1

      DataStore.invalidate(:test_site, :data)

      val2 = DataStore.fetch(:test_site, :data)
      assert val2 != val1
    end
  end

  describe "invalidate/3 with specific params" do
    setup do
      sources = [
        Source.new!(
          name: :item,
          fetch: fn params -> {params[:id], System.monotonic_time()} end,
          ttl: 60_000,
          params: [:id]
        )
      ]

      DataStore.register(:test_site, sources)
      :ok
    end

    test "busts only the specific params entry" do
      {1, ts1} = DataStore.fetch(:test_site, :item, %{id: 1})
      {2, ts2} = DataStore.fetch(:test_site, :item, %{id: 2})

      DataStore.invalidate(:test_site, :item, %{id: 1})

      # id=1 should re-fetch (new timestamp)
      {1, ts1_new} = DataStore.fetch(:test_site, :item, %{id: 1})
      assert ts1_new != ts1

      # id=2 should still be cached (same timestamp)
      {2, ts2_same} = DataStore.fetch(:test_site, :item, %{id: 2})
      assert ts2_same == ts2
    end
  end

  describe "subscribe/2 and PubSub broadcast" do
    setup do
      sources = [
        Source.new!(
          name: :live_data,
          fetch: fn _params -> System.monotonic_time() end,
          ttl: 60_000
        )
      ]

      DataStore.register(:test_site, sources)
      :ok
    end

    test "receives invalidation message after invalidate" do
      DataStore.subscribe(:test_site, :live_data)
      DataStore.invalidate(:test_site, :live_data)

      assert_receive {:beacon_data_store_invalidated, :live_data}, 1000
    end

    test "does not receive after unsubscribe" do
      DataStore.subscribe(:test_site, :live_data)
      DataStore.unsubscribe(:test_site, :live_data)
      DataStore.invalidate(:test_site, :live_data)

      refute_receive {:beacon_data_store_invalidated, :live_data}, 200
    end
  end

  describe "MFA fetch" do
    defmodule TestFetcher do
      def get_item(%{id: id}), do: %{id: id, name: "Item #{id}"}
      def list_all, do: [%{id: 1}, %{id: 2}]
    end

    test "calls module function with params extracted by name" do
      sources = [
        Source.new!(
          name: :item,
          fetch: {TestFetcher, :get_item, [:id]},
          ttl: 60_000,
          params: [:id]
        )
      ]

      DataStore.register(:test_site, sources)
      assert %{id: 42, name: "Item 42"} = DataStore.fetch(:test_site, :item, %{id: 42})
    end

    test "calls zero-arity function" do
      sources = [
        Source.new!(
          name: :all_items,
          fetch: {TestFetcher, :list_all, []},
          ttl: 60_000
        )
      ]

      DataStore.register(:test_site, sources)
      assert [%{id: 1}, %{id: 2}] = DataStore.fetch(:test_site, :all_items)
    end
  end
end
