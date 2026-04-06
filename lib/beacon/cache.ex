defmodule Beacon.Cache do
  @moduledoc false

  # Stampede-safe ETS cache. On miss, exactly one process executes the
  # load function while concurrent callers wait for the result.
  #
  # Uses :ets.insert_new/2 as an atomic lock — no GenServers, no
  # external dependencies, fully parallel across different keys.

  @poll_interval_ms 5
  @max_wait_ms 30_000

  @doc """
  Fetch a value from `table` under `key`. On miss, exactly one caller
  executes `load_fun/0`; others wait for the result.

  Returns the value directly or raises on error.
  """
  def fetch(table, key, load_fun) do
    case :ets.lookup(table, key) do
      [{^key, {:__loading__, ref, pid}}] ->
        await_result(table, key, ref, pid, load_fun)

      [{^key, value}] ->
        value

      [] ->
        ref = make_ref()

        if :ets.insert_new(table, {key, {:__loading__, ref, self()}}) do
          run_load(table, key, ref, load_fun)
        else
          # Lost race — retry (will see sentinel or value)
          fetch(table, key, load_fun)
        end
    end
  end

  defp run_load(table, key, ref, load_fun) do
    try do
      value = load_fun.()
      :ets.insert(table, {key, value})
      value
    catch
      kind, reason ->
        # Clean up only OUR sentinel
        :ets.match_delete(table, {key, {:__loading__, ref, self()}})
        :erlang.raise(kind, reason, __STACKTRACE__)
    end
  end

  defp await_result(table, key, ref, loader_pid, load_fun) do
    mon = Process.monitor(loader_pid)
    result = poll_loop(table, key, ref, loader_pid, mon, load_fun, deadline())
    Process.demonitor(mon, [:flush])
    result
  end

  defp poll_loop(table, key, ref, loader_pid, mon, load_fun, deadline) do
    case :ets.lookup(table, key) do
      [{^key, {:__loading__, ^ref, ^loader_pid}}] ->
        remaining = deadline - System.monotonic_time(:millisecond)

        if remaining <= 0 do
          raise "Beacon.Cache timeout waiting for #{inspect(key)}"
        end

        receive do
          {:DOWN, ^mon, :process, ^loader_pid, _reason} ->
            # Loader crashed — retry as a new loader
            fetch(table, key, load_fun)
        after
          min(@poll_interval_ms, remaining) ->
            poll_loop(table, key, ref, loader_pid, mon, load_fun, deadline)
        end

      [{^key, value}] ->
        value

      [] ->
        # Sentinel removed (loader failed) — retry
        fetch(table, key, load_fun)
    end
  end

  defp deadline, do: System.monotonic_time(:millisecond) + @max_wait_ms
end
