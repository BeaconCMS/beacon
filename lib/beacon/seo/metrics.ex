defmodule Beacon.SEO.Metrics do
  @moduledoc """
  Computes site-wide SEO metrics for measurement snapshots.
  """

  import Ecto.Query

  @doc """
  Computes comprehensive SEO metrics for a site.

  Returns a map with counts and percentages for key SEO indicators.
  """
  @spec compute(Beacon.Types.Site.t()) :: map()
  def compute(site) when is_atom(site) do
    repo = Beacon.Config.fetch!(site).repo
    site_str = Atom.to_string(site)

    pages =
      repo.all(
        from p in "beacon_pages",
          where: p.site == ^site_str,
          select: %{
            id: p.id,
            meta_description: p.meta_description,
            description: p.description,
            og_image: p.og_image,
            canonical_url: p.canonical_url,
            twitter_card: p.twitter_card,
            robots: p.robots,
            date_modified: p.date_modified,
            collection_id: p.collection_id,
            title: p.title
          }
      )

    total = length(pages)
    cutoff_90 = DateTime.utc_now() |> DateTime.add(-90 * 86_400, :second)

    structured_count = structured_count(repo, site_str)
    orphan_count = orphan_count(repo, site_str)
    broken_count = broken_count(repo, site_str)
    redirect_count = redirect_count(repo, site_str)

    %{
      "total_pages" => total,
      "pages_with_description" => count(pages, &has_description?/1),
      "pages_with_og_image" => count(pages, &non_empty?(&1.og_image)),
      "pages_with_structured_data" => structured_count,
      "pages_with_canonical" => count(pages, &non_empty?(&1.canonical_url)),
      "pages_with_collection" => count(pages, &(&1.collection_id != nil)),
      "pages_with_twitter_card" => count(pages, &non_empty?(&1.twitter_card)),
      "avg_seo_score" => average_score(pages, total),
      "stale_pages_count" => count(pages, &stale?(&1, cutoff_90)),
      "orphan_pages_count" => orphan_count,
      "broken_links_count" => broken_count,
      "redirect_count" => redirect_count
    }
  end

  defp structured_count(repo, site_str) do
    repo.one(
      from p in "beacon_pages",
        where: p.site == ^site_str and not is_nil(p.raw_schema) and p.raw_schema != ^[],
        select: count()
    ) || 0
  end

  # Pages no internal link points at.
  defp orphan_count(repo, site_str) do
    linked_ids =
      from(l in "beacon_internal_links",
        where: l.site == ^site_str and not is_nil(l.target_page_id),
        select: l.target_page_id,
        distinct: true
      )

    repo.one(
      from p in "beacon_pages",
        where: p.site == ^site_str and p.id not in subquery(linked_ids),
        select: count()
    ) || 0
  end

  defp broken_count(repo, site_str) do
    repo.one(
      from l in "beacon_internal_links",
        where: l.site == ^site_str and is_nil(l.target_page_id),
        select: count()
    ) || 0
  end

  defp redirect_count(repo, site_str) do
    repo.one(from r in "beacon_redirects", where: r.site == ^site_str, select: count()) || 0
  end

  defp has_description?(page), do: non_empty?(page.meta_description) or non_empty?(page.description)

  defp stale?(page, cutoff), do: page.date_modified == nil or DateTime.compare(page.date_modified, cutoff) == :lt

  defp average_score(_pages, 0), do: 0.0

  defp average_score(pages, total) do
    scores = Enum.map(pages, &page_score/1)
    Float.round(Enum.sum(scores) / total, 1)
  end

  # Percentage of the points a page earns across the SEO checks.
  defp page_score(page) do
    checks = score_checks(page)
    earned = checks |> Enum.filter(&elem(&1, 1)) |> Enum.map(&elem(&1, 0)) |> Enum.sum()
    total_possible = checks |> Enum.map(&elem(&1, 0)) |> Enum.sum()
    if total_possible > 0, do: earned / total_possible * 100, else: 0.0
  end

  defp score_checks(page) do
    description = page.meta_description || page.description

    [
      {10, non_empty?(page.title)},
      {10, within?(page.title, 60)},
      {10, has_description?(page)},
      {10, within?(description, 160)},
      {15, non_empty?(page.og_image)},
      {5, non_empty?(page.canonical_url)},
      {5, non_empty?(page.twitter_card)}
    ]
  end

  defp within?(value, max), do: non_empty?(value) and String.length(value || "") <= max

  defp count(pages, fun), do: Enum.count(pages, fun)

  defp non_empty?(nil), do: false
  defp non_empty?(""), do: false
  defp non_empty?(_), do: true
end
