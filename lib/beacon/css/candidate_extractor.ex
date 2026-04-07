defmodule Beacon.CSS.CandidateExtractor do
  @moduledoc """
  Extracts CSS class candidates from template strings.

  Uses a permissive regex that over-matches rather than under-matches.
  False positives add unused CSS (harmless). False negatives miss styles (broken).
  """

  # Tailwind candidate grammar:
  # - Starts with: a-z, 0-9, !, -, [, @
  # - Contains: a-z, 0-9, :, /, -, [, ], ., _, !, #, %, (, )
  # - Variants use : as separator (hover:, sm:, dark:)
  # - Modifiers use / (bg-red-500/50)
  # - Arbitrary values use [] (w-[calc(100%-2rem)])

  @doc """
  Extracts Tailwind CSS class candidates from a template string.

  Returns a `MapSet` of candidate strings. The extraction is deliberately
  permissive -- it is better to include a few false positives (which only
  add unused CSS) than to miss real classes (which would break styles).
  """
  @spec extract(binary()) :: MapSet.t(String.t())
  def extract(template) when is_binary(template) do
    template
    |> String.split(~r/[\s"'`<>={},;]/)
    |> Enum.filter(&valid_candidate?/1)
    |> MapSet.new()
  end

  defp valid_candidate?(token) do
    byte_size(token) > 1 and
      String.match?(token, ~r/^[!@a-z0-9\-\[]/i) and
      String.match?(token, ~r/^[a-z0-9!@\-\[\].:\/_#%()]*$/i) and
      not String.starts_with?(token, "//") and
      not String.starts_with?(token, "http") and
      not String.starts_with?(token, "{{") and
      not String.contains?(token, "==")
  end
end
