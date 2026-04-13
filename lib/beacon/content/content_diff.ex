defmodule Beacon.Content.ContentDiff do
  @moduledoc """
  Computes content differences between page versions to help editors
  determine if an edit is substantive enough to warrant bumping `date_modified`.

  Uses word-level token comparison. A change is considered "substantive" if
  >= 10% of tokens differ between the current template and the last published
  snapshot.
  """

  import Ecto.Query

  @substantive_threshold 0.10

  @doc """
  Compares the current page template against the last published snapshot.

  Returns:
    * `{:substantive, pct_changed}` — >= 10% of tokens changed
    * `{:minor, pct_changed}` — < 10% of tokens changed
    * `:no_previous` — no published snapshot exists to compare against
  """
  @spec compute(Beacon.Content.Page.t(), Beacon.Types.Site.t()) ::
          {:substantive, float()} | {:minor, float()} | :no_previous
  def compute(page, site) do
    repo = Beacon.Config.fetch!(site).repo

    last_template =
      from(s in Beacon.Content.PageSnapshot,
        where: s.site == ^site and s.page_id == ^page.id,
        order_by: [desc: s.inserted_at],
        limit: 1,
        select: s.template
      )
      |> repo.one()

    case last_template do
      nil ->
        :no_previous

      previous ->
        current_tokens = tokenize(page.template || "")
        previous_tokens = tokenize(previous)

        pct = token_change_percentage(current_tokens, previous_tokens)

        if pct >= @substantive_threshold do
          {:substantive, Float.round(pct, 4)}
        else
          {:minor, Float.round(pct, 4)}
        end
    end
  end

  @doc """
  Tokenizes a template into word tokens, stripping HTML/Beacon syntax tags.
  """
  @spec tokenize(String.t()) :: [String.t()]
  def tokenize(text) when is_binary(text) do
    text
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\{\{[^}]+\}\}/, " ")
    |> String.replace(~r/\{%[^%]+%\}/, " ")
    |> String.downcase()
    |> String.split(~r/\s+/, trim: true)
  end

  # Computes the percentage of tokens that differ using set-based comparison.
  defp token_change_percentage([], []), do: 0.0
  defp token_change_percentage(_current, []), do: 1.0
  defp token_change_percentage([], _previous), do: 1.0

  defp token_change_percentage(current, previous) do
    current_set = MapSet.new(current)
    previous_set = MapSet.new(previous)

    intersection = MapSet.intersection(current_set, previous_set) |> MapSet.size()
    union = MapSet.union(current_set, previous_set) |> MapSet.size()

    if union == 0, do: 0.0, else: 1.0 - intersection / union
  end
end
