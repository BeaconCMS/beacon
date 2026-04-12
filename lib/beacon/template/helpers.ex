defmodule Beacon.Template.Helpers do
  @moduledoc """
  Template helper functions for working with GraphQL data.

  GraphQL responses use JSON primitives — dates are ISO 8601 strings,
  numbers are JSON numbers, map keys are strings. These helpers provide
  formatting and parsing at the template level.

  ## Usage in HEEx templates

      <%= Beacon.Template.Helpers.format_datetime(@post["published_at"], "%B %d, %Y") %>
      <%= Beacon.Template.Helpers.format_datetime(@post["published_at"], "%-d %B %Y") %>

  ## Usage in components

      {my_component("ordinal_time", date: @post["published_at"])}
  """

  @doc """
  Format an ISO 8601 datetime string using Calendar.strftime format.
  Returns the formatted string, or the fallback if parsing fails.

      iex> format_datetime("2023-12-05T17:16:49Z", "%B %d, %Y")
      "December 05, 2023"
  """
  @spec format_datetime(binary() | DateTime.t() | NaiveDateTime.t() | nil, binary(), binary()) :: binary()
  def format_datetime(value, format, fallback \\ "")

  def format_datetime(nil, _format, fallback), do: fallback
  def format_datetime("", _format, fallback), do: fallback

  def format_datetime(%DateTime{} = dt, format, _fallback) do
    Calendar.strftime(dt, format)
  end

  def format_datetime(%NaiveDateTime{} = ndt, format, _fallback) do
    Calendar.strftime(ndt, format)
  end

  def format_datetime(value, format, fallback) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} ->
        Calendar.strftime(dt, format)

      _ ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, ndt} -> Calendar.strftime(ndt, format)
          _ -> fallback
        end
    end
  end

  def format_datetime(_, _format, fallback), do: fallback

  @doc """
  Convert an ISO 8601 datetime string to an ISO 8601 date string (for HTML `datetime` attribute).

      iex> to_iso_date("2023-12-05T17:16:49Z")
      "2023-12-05"
  """
  @spec to_iso_date(binary() | DateTime.t() | NaiveDateTime.t() | Date.t() | nil) :: binary()
  def to_iso_date(nil), do: ""

  def to_iso_date(%Date{} = d), do: Date.to_iso8601(d)
  def to_iso_date(%DateTime{} = dt), do: dt |> DateTime.to_date() |> Date.to_iso8601()
  def to_iso_date(%NaiveDateTime{} = ndt), do: ndt |> NaiveDateTime.to_date() |> Date.to_iso8601()

  def to_iso_date(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> dt |> DateTime.to_date() |> Date.to_iso8601()
      _ ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, ndt} -> ndt |> NaiveDateTime.to_date() |> Date.to_iso8601()
          _ ->
            case Date.from_iso8601(value) do
              {:ok, d} -> Date.to_iso8601(d)
              _ -> value
            end
        end
    end
  end

  def to_iso_date(_), do: ""
end
