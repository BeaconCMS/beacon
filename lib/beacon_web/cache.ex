# Copied and modified from https://github.com/hexpm/hexpm/blob/d5b4e3864e219dd8b2cca34570dbe60257bcc547/lib/hexpm_web/controllers/controller_helpers.ex
# Originally licensed under Apache 2.0 available at https://www.apache.org/licenses/LICENSE-2.0

defmodule BeaconWeb.Cache do
  @moduledoc false

  import Plug.Conn

  @max_cache_age 60

  def cache(conn, control, vary) do
    conn
    |> maybe_put_resp_header("cache-control", parse_control(control))
    |> maybe_put_resp_header("vary", parse_vary(vary))
  end

  # privacy can be: `:public` or `:private`
  def asset_cache(conn, privacy \\ :public) do
    control = [privacy, "max-age": @max_cache_age]
    vary = ["accept", "accept-encoding"]
    cache(conn, control, vary)
  end

  defp parse_vary(nil), do: nil
  defp parse_vary(vary), do: Enum.map_join(vary, ", ", &"#{&1}")

  defp parse_control(nil), do: nil

  defp parse_control(control) do
    Enum.map_join(control, ", ", fn
      atom when is_atom(atom) -> "#{atom}"
      {key, value} -> "#{key}=#{value}"
    end)
  end

  defp maybe_put_resp_header(conn, _header, nil), do: conn
  defp maybe_put_resp_header(conn, header, value), do: put_resp_header(conn, header, value)

  def when_stale(conn, entities, opts \\ [], fun) do
    etag = etag(entities)
    modified = if Keyword.get(opts, :modified, true), do: last_modified(entities)

    conn =
      conn
      |> put_etag(etag)
      |> put_last_modified(modified)

    if fresh?(conn, etag: etag, modified: modified) do
      send_resp(conn, 304, "")
    else
      fun.(conn)
    end
  end

  defp put_etag(conn, "") do
    conn
  end

  defp put_etag(conn, etag) do
    put_resp_header(conn, "etag", etag)
  end

  defp put_last_modified(conn, nil) do
    conn
  end

  defp put_last_modified(conn, modified) do
    put_resp_header(conn, "last-modified", to_rfc1123(modified))
  end

  def to_rfc1123(erl_datetime) when is_tuple(erl_datetime) do
    erl_datetime
    |> NaiveDateTime.from_erl!()
    |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")
  end

  defp fresh?(conn, opts) do
    not expired?(conn, opts)
  end

  defp expired?(conn, opts) do
    modified_since = List.first(get_req_header(conn, "if-modified-since"))
    none_match = List.first(get_req_header(conn, "if-none-match"))

    if modified_since || none_match do
      modified_since?(modified_since, opts[:modified]) or none_match?(none_match, opts[:etag])
    else
      true
    end
  end

  defp modified_since?(header, last_modified) do
    if header && last_modified do
      modified_since = :httpd_util.convert_request_date(String.to_charlist(header))
      modified_since = :calendar.datetime_to_gregorian_seconds(modified_since)
      last_modified = :calendar.datetime_to_gregorian_seconds(last_modified)
      last_modified > modified_since
    else
      false
    end
  end

  defp none_match?(none_match, etag) do
    if none_match && etag do
      none_match = Plug.Conn.Utils.list(none_match)
      etag not in none_match and "*" not in none_match
    else
      false
    end
  end

  def etag(entities) do
    binary =
      entities
      |> List.wrap()
      |> Enum.map(&BeaconWeb.Cache.Stale.etag/1)
      |> List.flatten()
      |> :erlang.term_to_binary()

    :md5
    |> :crypto.hash(binary)
    |> Base.encode16(case: :lower)
  end

  def last_modified(entities) do
    entities
    |> List.wrap()
    |> Enum.map(&BeaconWeb.Cache.Stale.last_modified/1)
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&time_to_erl/1)
    |> Enum.max()
  end

  defp time_to_erl(%NaiveDateTime{} = datetime), do: NaiveDateTime.to_erl(datetime)
  defp time_to_erl(%DateTime{} = datetime), do: NaiveDateTime.to_erl(datetime)
  defp time_to_erl(%Date{} = date), do: {Date.to_erl(date), {0, 0, 0}}
end
