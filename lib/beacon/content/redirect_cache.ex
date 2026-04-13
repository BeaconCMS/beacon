defmodule Beacon.Content.RedirectCache do
  @moduledoc false

  @table :beacon_redirects

  def init do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    end

    :ok
  end

  def load_redirects(site) do
    redirects = Beacon.Content.list_redirects(site, per_page: :infinity)

    for redirect <- redirects do
      put(redirect)
    end

    :ok
  end

  def lookup(site, path) when is_atom(site) and is_binary(path) do
    if :ets.whereis(@table) == :undefined do
      nil
    else
      case :ets.lookup(@table, {site, path}) do
        [{_, dest, status}] -> {dest, status}
        [] -> lookup_regex(site, path)
      end
    end
  end

  def put(redirect) do
    if redirect.is_regex do
      :ets.insert(@table, {{redirect.site, :regex, redirect.source_path, redirect.priority}, redirect.destination_path, redirect.status_code})
    else
      :ets.insert(@table, {{redirect.site, redirect.source_path}, redirect.destination_path, redirect.status_code})
    end
  end

  def delete(site, source_path) do
    :ets.delete(@table, {site, source_path})
  end

  def invalidate(site) do
    # Delete all entries for this site
    :ets.match_delete(@table, {{site, :_}, :_, :_})
    :ets.match_delete(@table, {{site, :regex, :_, :_}, :_, :_})
    load_redirects(site)
  end

  defp lookup_regex(site, path) do
    # Collect all regex patterns for this site, sorted by priority
    patterns = :ets.match(@table, {{site, :regex, :"$1", :"$2"}, :"$3", :"$4"})

    patterns
    |> Enum.sort_by(fn [_pattern, priority, _dest, _status] -> priority end)
    |> Enum.find_value(fn [pattern, _priority, dest, status] ->
      case Regex.compile(pattern) do
        {:ok, regex} ->
          if Regex.match?(regex, path) do
            resolved_dest = Regex.replace(regex, path, dest)
            {resolved_dest, status}
          end

        _ ->
          nil
      end
    end)
  end
end
