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

    pages = repo.all(from p in "beacon_pages", where: p.site == ^site_str,
      select: %{
        id: p.id,
        meta_description: p.meta_description,
        description: p.description,
        og_image: p.og_image,
        canonical_url: p.canonical_url,
        twitter_card: p.twitter_card,
        robots: p.robots,
        date_modified: p.date_modified,
        template_type_id: p.template_type_id,
        title: p.title
      })

    total = length(pages)
    cutoff_90 = DateTime.utc_now() |> DateTime.add(-90 * 86400, :second)

    # Structured data count
    structured_count = repo.one(
      from p in "beacon_pages",
      where: p.site == ^site_str and not is_nil(p.raw_schema) and p.raw_schema != ^[],
      select: count()
    ) || 0

    # Orphan pages
    linked_ids = from(l in "beacon_internal_links",
      where: l.site == ^site_str and not is_nil(l.target_page_id),
      select: l.target_page_id, distinct: true)
    orphan_count = repo.one(
      from p in "beacon_pages",
      where: p.site == ^site_str and p.id not in subquery(linked_ids),
      select: count()
    ) || 0

    # Broken links
    broken_count = repo.one(
      from l in "beacon_internal_links",
      where: l.site == ^site_str and is_nil(l.target_page_id),
      select: count()
    ) || 0

    # Redirect count
    redirect_count = repo.one(
      from r in "beacon_redirects", where: r.site == ^site_str, select: count()
    ) || 0

    # SEO score computation
    scores = Enum.map(pages, fn p ->
      checks = [
        {10, non_empty?(p.title)},
        {10, non_empty?(p.title) and String.length(p.title || "") <= 60},
        {10, non_empty?(p.meta_description) or non_empty?(p.description)},
        {10, non_empty?(p.meta_description || p.description) and String.length(p.meta_description || p.description || "") <= 160},
        {15, non_empty?(p.og_image)},
        {5, non_empty?(p.canonical_url)},
        {5, non_empty?(p.twitter_card)}
      ]
      earned = checks |> Enum.filter(&elem(&1, 1)) |> Enum.map(&elem(&1, 0)) |> Enum.sum()
      total_possible = checks |> Enum.map(&elem(&1, 0)) |> Enum.sum()
      if total_possible > 0, do: earned / total_possible * 100, else: 0.0
    end)

    avg_score = if total > 0, do: Float.round(Enum.sum(scores) / total, 1), else: 0.0

    %{
      "total_pages" => total,
      "pages_with_description" => count(pages, fn p -> non_empty?(p.meta_description) or non_empty?(p.description) end),
      "pages_with_og_image" => count(pages, fn p -> non_empty?(p.og_image) end),
      "pages_with_structured_data" => structured_count,
      "pages_with_canonical" => count(pages, fn p -> non_empty?(p.canonical_url) end),
      "pages_with_template_type" => count(pages, fn p -> p.template_type_id != nil end),
      "pages_with_twitter_card" => count(pages, fn p -> non_empty?(p.twitter_card) end),
      "avg_seo_score" => avg_score,
      "stale_pages_count" => count(pages, fn p ->
        p.date_modified == nil or DateTime.compare(p.date_modified, cutoff_90) == :lt
      end),
      "orphan_pages_count" => orphan_count,
      "broken_links_count" => broken_count,
      "redirect_count" => redirect_count
    }
  end

  defp count(pages, fun), do: Enum.count(pages, fun)

  defp non_empty?(nil), do: false
  defp non_empty?(""), do: false
  defp non_empty?(_), do: true
end
