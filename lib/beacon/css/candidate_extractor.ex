defmodule Beacon.CSS.CandidateExtractor do
  @moduledoc """
  Extracts CSS class candidates from template strings.

  Uses a permissive regex that over-matches rather than under-matches.
  False positives add unused CSS (harmless). False negatives miss styles (broken).
  """

  @doc """
  Extracts Tailwind CSS class candidates from a template string.

  Returns a `MapSet` of candidate strings. The extraction is deliberately
  permissive -- it is better to include a few false positives (which only
  add unused CSS) than to miss real classes (which would break styles).
  """
  @spec extract(binary()) :: MapSet.t(String.t())
  def extract(template) when is_binary(template) do
    template
    |> String.split(~r/[\s"'`<>{},;]/)
    |> Enum.filter(&valid_candidate?/1)
    |> MapSet.new()
  end

  defp valid_candidate?(token) do
    byte_size(token) > 1 and
      # Must start with a letter, digit, !, -, [, or @
      # (digits allowed for classes like 2xl:; pure-numeric tokens filtered below)
      String.match?(token, ~r/^[!@a-z0-9\-\[]/i) and
      # Must contain a letter somewhere (filters pure numeric tokens)
      String.match?(token, ~r/[a-z]/i) and
      # Only valid Tailwind characters
      String.match?(token, ~r/^[a-z0-9!@\-\[\].:\/_#%()=]*$/i) and
      # Exclude common non-class patterns
      not String.starts_with?(token, "//") and
      not String.starts_with?(token, "http") and
      not String.starts_with?(token, "{{") and
      not String.contains?(token, "==") and
      # Exclude SVG path commands (M, C, A, L, Z followed by numbers)
      not svg_path_data?(token)
  end

  # SVG path data looks like "M358.986", "C12.2-3.4", "A5.9847"
  # These are a single uppercase letter followed by digits/dots/dashes
  defp svg_path_data?(token) do
    String.match?(token, ~r/^[MmCcSsQqTtAaLlHhVvZz]\d/)
  end
end
