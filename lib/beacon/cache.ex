defmodule Beacon.Cache do
  @moduledoc false

  # Stampede-safe ETS cache with optional TTL.
  #
  # On miss (or expiration), exactly one process executes the load function
  # while concurrent callers wait for the result.
  #
  # Uses :ets.insert_new/2 as an atomic lock — no GenServers, no
  # external dependencies, fully parallel across different keys.
  #
  # Values are stored as `{key, {value, inserted_at}}` where `inserted_at`
  # is monotonic seconds. The sentinel `{key, {:__loading__, ref, pid}}`
  # is NOT wrapped — its 3-tuple shape distinguishes it from cached values.

  @poll_interval_ms 5
  @max_wait_ms 30_000

  @type ttl :: non_neg_integer() | :infinity

  @doc """
  Fetch a value from `table` under `key` with the given `ttl` (seconds).

  On miss or expiration, exactly one caller executes `load_fun/0`;
  others wait for the result.

  `ttl` can be:
    - a positive integer (seconds)
    - `:infinity` (never expires, only replaced on explicit write)

  Returns the value directly or raises on error.
  """
  def fetch(table, key, load_fun, ttl \\ :infinity) do
    case :ets.lookup(table, key) do
      [{^key, {:__loading__, ref, pid}}] ->
        await_result(table, key, ref, pid, load_fun, ttl)

      [{^key, {value, inserted_at}}] ->
        if expired?(inserted_at, ttl) do
          # Delete stale entry and re-load
          :ets.delete(table, key)
          fetch(table, key, load_fun, ttl)
        else
          value
        end

      # Legacy format (no timestamp) — treat as valid, will be timestamped on next write
      [{^key, value}] when not is_tuple(value) ->
        value

      [] ->
        ref = make_ref()

        if :ets.insert_new(table, {key, {:__loading__, ref, self()}}) do
          run_load(table, key, ref, load_fun)
        else
          # Lost race — retry (will see sentinel or value)
          fetch(table, key, load_fun, ttl)
        end
    end
  end

  @doc """
  Sweep expired entries from `table` that are older than `max_age` seconds.
  Entries with no timestamp are left untouched.
  """
  def sweep(table, max_age) when is_integer(max_age) and max_age > 0 do
    now = System.monotonic_time(:second)
    cutoff = now - max_age

    :ets.foldl(
      fn
        {_key, {:__loading__, _, _}}, acc -> acc
        {key, {_value, inserted_at}}, acc when inserted_at < cutoff ->
          :ets.delete(table, key)
          acc + 1
        _, acc -> acc
      end,
      0,
      table
    )
  end

  def sweep(_table, :infinity), do: 0

  defp expired?(_inserted_at, :infinity), do: false

  defp expired?(inserted_at, ttl) when is_integer(ttl) do
    System.monotonic_time(:second) - inserted_at > ttl
  end

  defp run_load(table, key, ref, load_fun) do
    try do
      value = load_fun.()
      :ets.insert(table, {key, {value, System.monotonic_time(:second)}})
      value
    catch
      kind, reason ->
        # Clean up only OUR sentinel
        :ets.match_delete(table, {key, {:__loading__, ref, self()}})
        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  defp await_result(table, key, ref, loader_pid, load_fun, ttl) do
    mon = Process.monitor(loader_pid)
    result = poll_loop(table, key, ref, loader_pid, mon, load_fun, ttl, deadline())
    Process.demonitor(mon, [:flush])
    result
  end

  defp poll_loop(table, key, ref, loader_pid, mon, load_fun, ttl, deadline) do
    case :ets.lookup(table, key) do
      [{^key, {:__loading__, ^ref, ^loader_pid}}] ->
        remaining = deadline - System.monotonic_time(:millisecond)

        if remaining <= 0 do
          raise "Beacon.Cache timeout waiting for #{inspect(key)}"
        end

        receive do
          {:DOWN, ^mon, :process, ^loader_pid, _reason} ->
            # Loader crashed — retry as a new loader
            fetch(table, key, load_fun, ttl)
        after
          min(@poll_interval_ms, remaining) ->
            poll_loop(table, key, ref, loader_pid, mon, load_fun, ttl, deadline)
        end

      [{^key, {value, inserted_at}}] ->
        if expired?(inserted_at, ttl) do
          :ets.delete(table, key)
          fetch(table, key, load_fun, ttl)
        else
          value
        end

      [{^key, value}] when not is_tuple(value) ->
        value

      [] ->
        # Sentinel removed (loader failed) — retry
        fetch(table, key, load_fun, ttl)
    end
  end

  defp deadline, do: System.monotonic_time(:millisecond) + @max_wait_ms
end
