defmodule Beacon.Client.Filters do
  @moduledoc """
  Built-in filter implementations for Beacon template rendering.

  Filters are the template's only data transformation mechanism.
  Every client SDK must implement the same set.

  ## Available Filters

  **Date:** `format_date`, `time_ago`
  **Text:** `truncate`, `upcase`, `downcase`, `strip_html`, `pluralize`
  **Numbers:** `format_number`
  **Collections:** `size`, `join`, `first`, `last`
  **Utility:** `default`, `json`
  """

  @doc """
  Apply a named filter to a value with the given arguments.
  """
  @spec apply(binary(), term(), [term()]) :: term()
  def apply(name, value, args \\ [])

  # -- Date --

  def apply("format_date", value, [format]) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> Calendar.strftime(dt, format)
      _ ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, ndt} -> Calendar.strftime(ndt, format)
          _ -> value
        end
    end
  end

  def apply("format_date", %DateTime{} = dt, [format]), do: Calendar.strftime(dt, format)
  def apply("format_date", %NaiveDateTime{} = ndt, [format]), do: Calendar.strftime(ndt, format)
  def apply("format_date", value, _), do: to_string(value)

  def apply("time_ago", value, _args) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> time_ago_in_words(dt)
      _ -> value
    end
  end

  def apply("time_ago", %DateTime{} = dt, _), do: time_ago_in_words(dt)
  def apply("time_ago", value, _), do: to_string(value)

  # -- Text --

  def apply("truncate", value, [length]) when is_binary(value) and is_integer(length) do
    if String.length(value) > length do
      String.slice(value, 0, length) <> "..."
    else
      value
    end
  end

  def apply("truncate", value, _), do: to_string(value)

  def apply("upcase", value, _) when is_binary(value), do: String.upcase(value)
  def apply("upcase", value, _), do: to_string(value)

  def apply("downcase", value, _) when is_binary(value), do: String.downcase(value)
  def apply("downcase", value, _), do: to_string(value)

  def apply("strip_html", value, _) when is_binary(value) do
    Regex.replace(~r/<[^>]*>/, value, "")
  end

  def apply("strip_html", value, _), do: to_string(value)

  def apply("pluralize", count, [singular, plural]) when is_integer(count) do
    if count == 1, do: "#{count} #{singular}", else: "#{count} #{plural}"
  end

  def apply("pluralize", value, _), do: to_string(value)

  # -- Numbers --

  def apply("format_number", value, []) when is_integer(value) do
    value
    |> Integer.to_string()
    |> add_thousands_separator()
  end

  def apply("format_number", value, [precision]) when is_float(value) and is_integer(precision) do
    :erlang.float_to_binary(value, decimals: precision)
  end

  def apply("format_number", value, _), do: to_string(value)

  # -- Collections --

  def apply("size", value, _) when is_list(value), do: length(value)
  def apply("size", value, _) when is_binary(value), do: String.length(value)
  def apply("size", value, _) when is_map(value), do: map_size(value)
  def apply("size", _, _), do: 0

  def apply("join", value, [separator]) when is_list(value) do
    Enum.join(value, separator)
  end

  def apply("join", value, []) when is_list(value), do: Enum.join(value, ", ")
  def apply("join", value, _), do: to_string(value)

  def apply("first", [head | _], _), do: head
  def apply("first", _, _), do: nil

  def apply("last", list, _) when is_list(list) and length(list) > 0, do: List.last(list)
  def apply("last", _, _), do: nil

  # -- Utility --

  def apply("default", nil, [fallback]), do: fallback
  def apply("default", "", [fallback]), do: fallback
  def apply("default", false, [fallback]), do: fallback
  def apply("default", value, _), do: value

  def apply("json", value, _), do: Jason.encode!(value)

  # -- Unknown filter --

  def apply(_name, value, _args), do: value

  # -- Private helpers --

  defp time_ago_in_words(dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 2_592_000 -> "#{div(diff, 86400)} days ago"
      diff < 31_536_000 -> "#{div(diff, 2_592_000)} months ago"
      true -> "#{div(diff, 31_536_000)} years ago"
    end
  end

  defp add_thousands_separator(str) do
    str
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
end
