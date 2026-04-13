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
    pages = repo.all(from p in "beacon_pages", where: p.site == ^Atom.to_string(site),
      select: %{
        meta_description: p.meta_description,
        description: p.description,
        og_image: p.og_image,
        canonical_url: p.canonical_url,
        page_type: p.page_type,
        twitter_card: p.twitter_card,
        date_modified: p.date_modified,
        author_id: p.author_id
      })

    total = length(pages)
    cutoff_90 = DateTime.utc_now() |> DateTime.add(-90 * 86400, :second)

    %{
      "total_pages" => total,
      "pages_with_description" => count(pages, fn p -> non_empty?(p.meta_description) or non_empty?(p.description) end),
      "pages_with_og_image" => count(pages, fn p -> non_empty?(p.og_image) end),
      "pages_with_canonical" => count(pages, fn p -> non_empty?(p.canonical_url) end),
      "pages_with_author" => count(pages, fn p -> p.author_id != nil end),
      "pages_article_type" => count(pages, fn p -> p.page_type == "article" end),
      "pages_with_twitter_card" => count(pages, fn p -> non_empty?(p.twitter_card) end),
      "stale_pages_count" => count(pages, fn p ->
        p.date_modified == nil or DateTime.compare(p.date_modified, cutoff_90) == :lt
      end),
      "redirect_count" => repo.one(from r in "beacon_redirects", where: r.site == ^Atom.to_string(site), select: count())
    }
  end

  defp count(pages, fun), do: Enum.count(pages, fun)

  defp non_empty?(nil), do: false
  defp non_empty?(""), do: false
  defp non_empty?(_), do: true
end
